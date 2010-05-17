package Storage;

use strict;
use warnings;

use Storable qw();

use Storage::Mapper;
use Storage::Status;
use Storage::Type;
use Storage::Structure;
use Storage::Transaction;

use Storage::Auth;
use Storage::Auth::User;
use Storage::Auth::Role;

use Digest::MD5 qw(md5_hex);

our $VERSION = '0.0.1';

our $TRANSACTION = Storage::Transaction->create_singleton();

sub new {
    my $class = shift;
    my $self  = {};
    my %data = @_;
    
    my $status = $self->{status} = $data{status} || new Storage::Status();

    unless ($data{engine}) {
	$status->set( 404, "No engine specified?" );
	return undef;
    }
    
    my $engine = join(".", $data{engine}, "pm" );
    
    # Throw-away object, used to get access to class methods.
    bless $self, $class;

    my $path = join('/', $self->_storage_path(), 'Engine');

    my $db;
    if (opendir( my $dh, $path )) {
	( $db ) = grep { $_ eq $engine } readdir $dh;
	closedir $dh;
    } else {
	$status->set( 503, "Unable to find engines under $path: $!");
      return undef;
    }

    if( $db ) {
	$db =~ s/\.pm//;
	my $engine_class = join("::", __PACKAGE__, 'Engine', $db );
	eval qq( require $engine_class );
	
	if ($@) {
	    $status->set( 500, $@ );
	    return undef;
	}
	
	my $storage = $engine_class->new(@_);
	$storage->_set_default_user("nobody");

	$storage->{transaction} = $TRANSACTION;
	$storage->{type} = new Storage::Type();
	
	unless (defined $storage) {
	    $status->set( 500 );
	    return undef;
	}

	$storage->{status} = $status;
	$storage->{mapper} = $data{mapper};

	if ($data{cache}) {
	    if (ref $data{cache} eq 'HASH') {
		$storage->{cache} = $data{cache};
	    } else {
		Yggdrasil::fatal( "The cache parameter needs to be a hash reference, not a " . ref $data{cache} );
	    }
	} else {
	    $storage->{cache} = {};
	}
	
	# Structure the internals of Storage. Reads the Storage_* structures.
	$storage->{structure} = new Storage::Structure( storage => $storage );
	$storage->{structure}->init();
	
	return $storage;
    }
}

sub version {
    return $VERSION;
}

sub _engine {
    my $self = shift;

    my $engine = ref $self;
    $engine =~ s/^.*:://;
    return $engine;
}

sub debug {
    my $self = shift;
    my %params = @_;

    for my $key ( keys %params ) {
	$self->{_debug}->{$key} = $params{$key};
    }
}

sub _set_default_user {
    my $self = shift;
    my $user = shift;

    my $u = Storage::Auth::User->get_nobody( $self );
    $self->{user} = $u;
}

sub _set_bootstrap_user {
    my $self = shift;

    my $u = Storage::Auth::User->get_bootstrap( $self );
    $self->{user} = $u;
}

sub _is_bootstrapping {
    my $self = shift;
    return $self->{user}->id() == 1;
}

sub user {
    my $self = shift;

    return $self->{user};
}

sub bootstrap {
    my $self  = shift;
    my %users = @_;

    my $status = $self->{status};
    $self->_set_bootstrap_user();

    # Create main infrastructure
    $self->{structure}->bootstrap();

    # Create default users and roles
    my %roles;
    for my $role ( qw/admin user/ ) {
	$roles{$role} = Storage::Auth::Role->define( $self, $role );
    }

    # create bootstrap and nobody, the order is relevant as bootstrap
    # is required to be ID1 and nobody is ID2.    
    my $nobody_role    = Storage::Auth::Role->define( $self, "nobody" );
    my $bootstrap_user = Storage::Auth::User->define( $self, "bootstrap", undef );
    my $nobody_user    = Storage::Auth::User->define( $self, "nobody", undef );

    $nobody_role->description( 'System role' );
    $bootstrap_user->fullname( 'Bootstrapper extraordinare' );
    $nobody_user->fullname( 'Mr. Nobody' );

    $nobody_role->add( $nobody_user );
    $nobody_role->grant( $self->get_structure( 'authuser' ) => 'r',
			 id => $nobody_user->id() );

    my %usermap;

    # Ensure that the default user and root are created, retaining their
    # assigned passwords if any are given.
    my $me = getpwuid( $> ) || 'default';
    $users{$me}    = undef unless $users{$me};
    $users{'root'} = undef unless $users{'root'};

    for my $user ( keys %users ) {
	my $pwd = $users{$user};
	my $auth = new Storage::Auth;
	$pwd ||= $auth->generate_password();

	my $u = Storage::Auth::User->define( $self, $user, $pwd );

	for my $rolename ( keys %roles ) {
	    my $role = $roles{$rolename};
	    $role->add( $u );
	    $role->grant( $self->get_structure( 'authuser' ) => 'm', 
			  id => $u->id() );

	    $nobody_role->grant( $self->get_structure( 'authuser' ) => 'r', 
				 id => $u->id() );
	}

	if ($user eq "root") {
	    $u->fullname( 'root' );
	    $self->{user} = $u;
	}
	$usermap{$user} = $pwd;
    }

    # Give admin users access to read about the system users.
    $roles{admin}->grant( $self->get_structure( 'authuser' ) => 'r',
			  id => $nobody_user->id() );
    $roles{admin}->grant( $self->get_structure( 'authrole' ) => 'r',
			  id => $nobody_role->id() );
    $roles{admin}->grant( $self->get_structure( 'authuser' ) => 'r',
			  id => $bootstrap_user->id() );

    return %usermap;
}

sub get_status {
    my $self = shift;
    return $self->{status};
}

# define( Schema',
#         fields   => { field1, 
#                               { null  => BOOL(0), type => type(TEXT),
#                                 index => BOOL(0), constraint => constraint(undef) }
#                       field2, 
#                               { null  => BOOL(0), type => type(TEXT), 
#                                 index => BOOL(0), constraint => constraint(undef) }
#         temporal => BOOL(0),
#         nomap => BOOL(0),
#         hints => { field1 => { key => BOOL(0), foreign => 'Schema', index => BOOL(0) }}
# );
sub define {
    my $self = shift;
    my $schema = shift;
    
    my $transaction = $TRANSACTION->init( path => 'define' );

    my %data = @_;
    my $originalname = $schema;
    my $status = $self->get_status();

    for my $fieldhash (values %{$data{fields}}) {	
	my $type = uc $fieldhash->{type};
	if ($type eq 'SERIAL' && $fieldhash->{null}) {
	    $fieldhash->{null} = 0;
	}
	$fieldhash->{type} = $self->_check_valid_type( $type );	
    }

    $schema = $self->_map_schema_name( $schema ) unless $data{nomap};

    if ($self->_structure_exists( $schema )) {
	$status->set( 202, "Structure '$schema' already existed" );
	return;
    }

    if( $data{temporal} ) {
	# Add temporal field
	$data{fields}->{start} = { type => 'INTEGER', null => 0 };
	$data{fields}->{stop}  = { type => 'INTEGER', null => 1 };
	$data{hints}->{start}  = { foreign => $self->get_structure( 'ticker' ), key => 1 };
	$data{hints}->{stop}   = { foreign => $self->get_structure( 'ticker' ) };
    } else {
	# Add tick field unless we're dealing with the ticker schema.
	unless ( $schema eq $self->get_structure( 'ticker' ) ) {
	    $data{fields}->{tick} = { type => 'INTEGER', null => 0 };
	}
    }

    for my $field (keys %{$data{fields}}) {
	for my $typedata (keys %{$data{fields}->{$field}}) {
	    if ($typedata eq 'filter') {
		my $filters = $data{fields}->{$field}->{$typedata};
		
		if (ref $filters eq 'ARRAY' ) {
		    # Pass. Good work!
		} elsif (ref $filters) {
		    $status->set( 406, "Malformed filter data format" );
		    return;
		} else {
		    $filters = [ $filters, undef ];
		}

		my @fieldfilters;
		for( my $i=0; $i < @$filters; $i += 2 ) {
		    my ($filter, $params) = ($filters->[$i], $filters->[$i+1]);
		    
		    $self->store( $self->get_structure( 'filter' ), key => "schemaname",
				  fields => { schemaname => $originalname, filter => $filter,
					      field  => $field, params => $params });
		    push @fieldfilters, { filter => $filter, field => $field, params => $params };
		}
		$self->cache( 'filter', $originalname, \@fieldfilters);
	    }
	}
    }
    
    $transaction->log( "Defined $originalname" );
    my $tick = $self->tick( 'define', $schema ) unless $schema eq $self->get_structure( 'ticker' );
    my $retval = $self->_define( $schema, %data );

    # Store the define statement for reference to help dump / restore.
    # Use _store to avoid ticking.  FIXME, check return value?
    my $storage_prefix = $self->{structure}->internal( 'prefix' );
    unless ($originalname =~ /^$storage_prefix/) {
	my @define = ( $originalname => %data );
	$self->_store( $self->get_structure( 'defines' ),
		       key => 'tick',
		       fields => {
				  tick   => $tick,
				  define => Storable::nfreeze( \@define ),
				 });
    }
    
    if ($retval) {
	unless ($data{nomap}) {
	    $self->cache( 'mapperh2m', $originalname, $schema );
	    $self->cache( 'mapperm2h', $schema, $originalname );
	    $self->store( $self->get_structure( 'mapper' ), key => "humanname",
			  fields => { humanname => $originalname, mappedname => $schema });
	}
	if ($data{temporal}) {
	    $self->cache( 'temporal', $schema, 1 );
	    $self->store( $self->get_structure( 'temporal' ), key => "tablename",
			  fields => { tablename => $schema, temporal => 1 });
	}

	if( $data{auth} ) {
	    $self->{structure}->_define_auth( $schema, $originalname, $data{auth}, $data{nomap}, $data{authschema} );
	}
    }
    
    $transaction->commit();
    return $retval;
}

sub _find_schema_by_name_or_alias {
    my $self = shift;
    my $name = shift;
    my $definitions = shift;
    
    my @matches;

    for( my $i=0; $i<@$definitions; $i+=2 ) {
	my $schema      = $definitions->[$i];
	my $constraints = $definitions->[$i+1];

	my $found = 0;
	if( $schema eq $name ) { $found = 1 }
	if( defined $constraints->{alias} && $constraints->{alias} eq $name ) { $found = 1 };

	push( @matches, $constraints ) if $found;
    }

    return @matches;
}


# store ( schema, key => id|[f1,f2...], fields => { fieldname => value, fieldname2 => value2 })
sub store {
    my $self = shift;
    my $schema = shift;
    my %params = @_;

    my $status = $self->get_status();
    my $transaction = $TRANSACTION->init( path => 'store' );

    my $uname = $self->{user}->id();

    # Apply filters right away.
    my $filterset = $self->cache( 'filter', $schema );
    if ($filterset) {
	for my $fieldname_to_store (keys %{$params{fields}}) {
	    for my $filterref (@$filterset) {
		if ($filterref->{field} eq $fieldname_to_store) {
		    $params{fields}->{$fieldname_to_store} =
		      $self->{type}->apply_filter( $filterref->{filter},
						   'store',
						   $params{fields}->{$fieldname_to_store},
						   $filterref->{params},
						 );
		}
	    }	    
	}
    }

    # build key/value mapping of keys that are supposed to uniqly
    # identify the entry we (are going to) work on.
    my %keys;
    my $key = $params{key};
    if( ref $key eq 'ARRAY' ) {
	for my $k (@$key) {
	    $keys{$k} = $params{fields}->{$k};
	}
    } else {
	$keys{$key} = $params{fields}->{$key};
    }

    # Check if the entry exists
    my $real_schema = $self->_get_schema_name( $schema ) || $schema;
    my $aref = $self->_fetch( $real_schema => { where => [ %keys ] } );

    my $update = 0;
    if( @$aref ) {
	# An entry exists - we have to check if the values for the
	# entry are the same as those we are trying to set
	my $values = $aref->[0];
	my $fields = $params{fields};
	my $equal  = 1;
	foreach my $field ( keys %$fields ) {
	    if( ! exists $values->{$field} || $fields->{$field} ne $values->{$field} ) { 
		# FIX: "ne"? should use a proper equality test, !=,
		# ne, other?
		$equal = 0;
		last;
	    }
	}

	# We have to do this even if equal==1 in order to figure out a
	# proper status response
	my $can = $self->can( update => $real_schema, \%keys );

	if( $equal ) {
	    # Trying to update an entry with values that already are
	    # current
	    if( $can ) { 
		$status->set( 202, "Value(s) already set" );

		# FIX: what if the key is a composite key?
		return $aref->[0]->{$key};
	    }
	    else { 
		$status->set( 403, "Forbidden" ); 
		return;
	    }
	} else {
	    # New values
	    unless( $can ) {
		# ... but not the proper rights
		$status->set( 403, "Forbidden" );
		return;
	    }

	    # note for later that we should perform an update
	    $update = 1;
	}
    } else {
	# An entry does not exists - check to see if we are allowed to
	# create stuff
	my $can = $self->can( create => $real_schema, \%keys );
	unless( $can ) {
	    $status->set( 403, "Forbidden" );
	    return;
	}
    }

    # Tick
    my $tick = $self->tick( $update?'update':'store', $real_schema );    
    unless( $self->_schema_is_temporal($real_schema) ) {
	$params{fields}->{tick} = $tick;
    }

    # If we are updating, expire the old value
    if( $update ) {
	$transaction->log( "Expire: $schema " . join( ", ", map { defined()?$_:"" } %keys ) );
	$self->_expire( $real_schema, $tick, %keys );
    }

    $transaction->log( "Store: $schema " . join( ", ", map { defined()?$_:"" } %keys ) );
    $transaction->commit();    
    my $r = $self->_store( $real_schema, tick => $tick, %params );
    my $user = $self->user();
    
    unless ($self->_is_bootstrapping()) {
	if( $self->cache( 'hasauthschema', $schema ) ) {
	    for my $role ( $user->member_of() ) {
		$role->grant( $real_schema => 'm', id => $r );
	    }
	}
    }    

    return $r;
}

sub tick {
    my $self   = shift;
    my $event  = shift;
    my $schema = shift;
    my $c = $self->{user}->name();

    my $tickerschema = $self->_get_schema_name($self->get_structure( 'ticker' )) || $self->get_structure( 'ticker' );
    return $self->_store( $tickerschema, fields => {
						    committer => $c,
						    event     => $event,
						    target    => $schema,
						   } );
}

sub get_ticks {
    my $self   = shift;
    my %params = @_;

    my %fetch = ( return => '*' );
    if( $params{start} ) {
	my @where = ( id => $params{start} );
	my @op    = ( '>=' );

	if( $params{stop} ) {
	    push( @where, id => $params{stop} );
	    push( @op, '<=' );
	}
	$fetch{where} = \@where;
	$fetch{operator} = \@op;
    } elsif( $params{id} ) {
	$fetch{where} = [ id => $params{id} ];
    } else {
	return;
    }
    
    return $self->fetch( $self->get_structure('ticker') => \%fetch );
}

# At this point we should be getting epochs to work with.
sub get_ticks_from_time {
    my ($self, $from, $to) = @_;

    $from = $self->_convert_time( $from );
    my $fetchref;
    if ($to) {
	$to = $self->_convert_time( $to );

	$fetchref = $self->fetch( 'Storage_ticker', { return => [ 'id', 'stamp', 'committer' ],
						      where  => [ 'stamp' => \qq<$from>, stamp => \qq<$to> ],
						      operator => [ '>=', '<='],
						      bind   => 'and',
						    } );

    } else {
	my $max_stamp = $self->fetch( Storage_ticker => { return   => "stamp",
							  filter   => "MAX",
							  where    => [ stamp => \qq<$from> ],
							  operator => "<=",
							} );

	$max_stamp = $max_stamp->[0]->{max_stamp};
	return unless $max_stamp;

	$fetchref = $self->fetch( 'Storage_ticker', { return => [ 'id', 'stamp', 'committer' ],
						      where  => [ 'stamp' => $max_stamp ],
						      operator => '=',
						    } );

	
    }

    my @hits;
    for my $tick (sort { $a->{id} <=> $b->{id}  } @$fetchref) {
	push @hits, $tick;
    }
    return @hits;
}

sub raw_store {
    my $self = shift;
    my $schema = shift;
    $self->_admin_verify();
    
    my $mapped = $self->_get_schema_name( $schema ) || $schema;
    return $self->_raw_store( $mapped, @_ );
}

# fetch ( schema1, { return => [ fieldnames ], where => [ s1field1 => s1value1, ... ], operator => operator, bind => bind-op }
#         schema2, { return => [ fieldnames ], where => [ s2field => s2value, ... ], operator => operator, bind => bind-op }
#         { start => $start, stop => $stop } (optional)
# We remap the schema names (the non-reference parameters) here.
sub fetch {
    my $self = shift;
    my @targets;

    my $transaction = $TRANSACTION->init( path => 'fetch' );
    
    my $time;
    if( @_ % 2 ) { 
	$time = pop @_;
    } else {
	$time = {};
    }

    # Convert the given timeformat to the engines preferred format
    # Turned off for ticks.
#    foreach my $key ( keys %$time ) {
#	$time->{$key} = $self->_convert_time( $time->{$key} );
#    }

    # Add "as" parameter that can be used later to prefix returned values from the query
    # (to ensure unique return values, eg. Foo_stop, Bar_stop, ... )
    my @schemas_looked_at;
    for( my $i=0; $i < @_; $i += 2 ) {
	my( $schema, $queryref ) = ($_[$i], $_[$i+1]);
	push @schemas_looked_at, $schema;
	next unless $queryref->{join} || $queryref->{as};
	$queryref->{as} = $schema;
	push @targets, $schema;
    }

    $transaction->log( "Fetch: " . join( ', ', @schemas_looked_at) );

    my @schemadefs = @_;
    unless ($self->_is_bootstrapping()) {
	# Add auth bindings to query
	my @authdefs = $self->_add_auth( "fetch", \@schemadefs );
	push( @schemadefs, @authdefs );
    }

    # map schema names
    @schemadefs = $self->_map_fetch_schema_references( @schemadefs );

    my $ref = $self->_fetch( @schemadefs, $time );
    $transaction->commit();
    return $ref;
}

sub _add_auth {
    my $self       = shift;
    my $authtype   = shift;
    my $schemadefs = shift;
    my $map        = shift;
    
    my @authdefs;
    for( my $i=0; $i<@$schemadefs; $i+=2 ) {
	my $schema = $schemadefs->[$i];
	my $schemabindings = $schemadefs->[$i+1];

	# 1. Find auth-bindings for this schema
	my $cachename = $schema . ':' . $authtype;
	my $typebindings; # = $self->cache( 'authbindings', $cachename );
	unless ($typebindings) {
	    my $ret = $self->_fetch( $self->get_structure( 'authschema' ) =>
				     {
				      return => 'bindings',
				      where  => [ usertable => $schema, type => $authtype ]
				     } );
	    next unless $ret;
	    
	    my $frozen_bindings = $ret->[0]->{bindings};
	    $typebindings = Storable::thaw( $frozen_bindings );
#	    $self->cache( 'authbindings', $cachename, $typebindings );
	}
	next unless $typebindings;

	# 2. Assign uniq alias for each auth-table.  FIXME for rand.
	for( my $j=1; $j<@$typebindings; $j+=2 ) {
	    my $authschema_constraint = $typebindings->[$j];

	    # Add a new uniq alias.  FIXME for rand.
	    my $uniq_alias = join("_", "_auth", int(rand()*100_000) );
	    $authschema_constraint->{_auth_alias} = $uniq_alias;
	}

	# 3. Find any references (\q<>) in the bindings where clause,
	#    change this to use any aliases (alias or _auth_alias)
	my @membership;
	for( my $j=0; $j<@$typebindings; $j+=2 ) {
	    my $authschema = $typebindings->[$j];
	    my $authconstraint = $typebindings->[$j+1];

	    my $where = $authconstraint->{where};
	    next unless $where;

	    for( my $k=1; $k<@$where; $k+=2 ) {
		my $ref = $where->[$k];
		next unless ref $ref eq "SCALAR";

		# ref is either a string with the pattern
		# "tablename.fieldname" or the name of a parameter we
		# are to fetch from the map if the latter is the case,
		# ref does not contain the character "."
		my( $target, $field ) = split m/\./, $$ref;
		
		if( defined $field ) {
		    if( $target eq $schema ) {
			# The $target references this schema - if this
			# schema is defined to use an alias, then we'll
			# change the reference to use this schemas alias
			# instead.
			if( $schemabindings->{alias} ) {
			    $target = $schemabindings->{alias};
			    $where->[$k] = \ join(".", $target, $field);
			}
		    } else {
			# Change all other schema references to use the
			# auth alias created in step 3
			my @matches = $self->_find_schema_by_name_or_alias( $target, $typebindings );
			$where->[$k] = \ join(".", $matches[0]->{_auth_alias}, $field );
		    }
		} else {
		    # target holds the name of the parameter we are to
		    # fetch from the map
		    unless( $map || ! exists $map->{$target} ) { 
			# FIX: complain about not being able to substitute
			return;
		    }
		    
		    $where->[$k] = $map->{$target};
		}
	    }	    
	    
	    # Add test for the roles a user is member of.
	    my $alias = $authconstraint->{_auth_alias};
	    my $member = {
			  where => [
				    userid => $self->user()->id(),
				    roleid => \qq<$alias.roleid>,
				   ],
			  alias => join("_", "_auth", int(rand() * 100_000) ),
			 };
	    
	    push( @membership, $self->get_structure( 'authmember' ), $member );
	}

	# 4. set alias = _auth_alias and remove _auth_alias
 	for( my $i=1; $i<@$typebindings; $i+=2 ) {
 	    my $constraint = $typebindings->[$i];
 	    $constraint->{alias} = $constraint->{_auth_alias};
 	    delete $constraint->{_auth_alias};
 	}

	push( @authdefs, @$typebindings, @membership );
    }

    return @authdefs;
}

sub can {
    my $self   = shift;
    my $type   = shift;
    my $schema = shift;
    my $map    = shift;

#    print "Entering can( $type, $schema, { ", join(", ", map { "$_ => $map->{$_}" } keys %$map ), " }\n";

    return 1 if $self->_is_bootstrapping();

    my @schemadefs = ( $schema => {} );
    if( $type ne "create" ) {
	# we can use the map as basis for a select for data that
	# exists, but we can't use it as a basis for a select for data
	# not yet in existance
	@schemadefs = ( $schema => { where => [ %$map ] } );
    }

    my @authdefs = $self->_add_auth( $type, \@schemadefs, $map );
    return 1 unless @authdefs;

    if( $type eq "create" ) {
	# clear out our dummy schemadefs
	@schemadefs = ();
    }

    my $r = $self->_fetch( @schemadefs, @authdefs );

    if( @$r ) {
#	print " -> Yes we can!\n";
	return 1;
    } else {
#	print " -> No we can not!\n";
	return;
    }
}

sub _map_fetch_schema_references {
    my $self = shift;
    my @defs = @_;

    my @mapped_def;
    while( @defs ) {
	my( $schema, $struct ) = ( shift @defs, shift @defs );

	# Map schema names mentioned inside the fetch
	for my $lfield ( keys %$struct ) {
	    my $val = $struct->{$lfield};
	    next unless ref $val eq "SCALAR";

	    $val = $$val;
	    next unless $val =~ /:/;

	    my @parts = split m/\./, $val;
	    my $rfield = pop @parts;
	    
	    my $mapped = $self->_get_schema_name( join(".", @parts) );
	    next unless $mapped;

	    $mapped .= "." . $rfield;
	    $struct->{$lfield} = \$mapped;
	}

	# Map the schema name itself
	my $mapped = $self->_get_schema_name( $schema ) || $schema;

	push( @mapped_def, $mapped, $struct );
    }

    return @mapped_def;
}

sub authenticate {
    my $self = shift;
    my %params = @_;
    
    my ($user, $pass, $session) = ($params{'username'}, $params{'password'}, $params{'session'});

    my $status = $self->get_status();
    my $user_obj;

    if (defined $user && defined $pass) {
	# First, we got both a username and a password.
	$user_obj = Storage::Auth::User->get( $self, $user );

	if( $user_obj ) {
	    my $filterset = $self->cache( 'filter', $self->get_structure( 'authuser:password' ) );
	    if ($filterset) {
		my ($pwfilter, $params) = ($filterset->[0]->{filter}, $filterset->[0]->{params});
		$pass = $self->{type}->apply_filter( $pwfilter, 'store', $pass, $params );
	    }

	    my $realpass = $user_obj->password() || '';

	    if (! defined $pass || $pass ne $realpass) {
		$user_obj = undef;
	    }
	}
	$session = undef;
    } elsif ($session) {
	# Or, we got a session id - see if we find a user with this session id	
	$user_obj = Storage::Auth::User->get_by_session( $self, $session );
    } elsif (-t && ! defined $user && ! defined $pass) {
	# Lastly, let see if we're connected to a tty without getting a
	# username / password, at which point we're already authenticated
	# and we don't want to touch the session.  $> is effective UID.
	my $uname = (getpwuid($>))[0];
	$user_obj = Storage::Auth::User->get( $self, $uname );
	$session = "invalid";
    }

    if( $user_obj ) {
	$self->{user} = $user_obj;
	unless ($session) {
	    $session = md5_hex(time() * $$ * rand(time() + $$));
	    $user_obj->session( $session );
	}
	$self->{session} = $session;
	$status->set( 200 );
    } else {
	$status->set( 403 );
    }

    return $user_obj;
}

sub raw_fetch {
    my $self = shift;
    $self->_admin_verify();
    
    my @mapped_def = $self->_map_fetch_schema_references( @_ );

    return $self->_raw_fetch( @mapped_def );
}

# expire ( $schema, $indexfield, $key )
# FIXME, handle multiple keys
sub expire {
    my $self   = shift;
    my $schema = shift;
    
    my $real_schema = $self->_get_schema_name( $schema ) || $schema;

    unless ($self->_schema_is_temporal( $real_schema )) {
	$self->get_status()->set( 406, "Expire of a non-temporal value attempted" );
	return;
    }

    # can?
    my $able = $self->can( expire => $real_schema, { @_ } );
    unless ($able) {
	$self->get_status()->set( 403 );
	return;
    }

    # Tick
    my $tick = $self->tick( 'expire', $real_schema );

    # Do not test return values, just pass them back to the caller.
    $self->_expire( $real_schema, $tick, @_ );
}

# exists ( schema, field, value ) 
sub exists :method {
    my $self = shift;
    my $schema = shift;

    my $mapped_schema = $self->_get_schema_name( $schema ) || $schema;
    return undef unless $self->_structure_exists( $mapped_schema );
    return $self->fetch( $mapped_schema, { return => '*', where => [ @_ ] });
}


sub _convert_time {    
    my $self = shift;
    my $time = shift;

    return $time;
}

sub _isepoch {
    my $self = shift;
    my $time = shift;

    return 1 if $time =~ /^\d+$/;
}

sub _isisodate {
    my $self = shift;
    my $time = shift;

    # FIX: Write me!
}

# Map structure names into a given hash, this is done to allow usage
# of any name into a schema name, character sets and reserved words
# are no constraints.
sub _map_schema_name {
    my $self = shift;
    my $schema = shift;
    
    my $status = $self->get_status();

    unless ($schema) {
	$status->set( 500, "No schema given to _map_schema_name" );
	return undef;
    }

    my $current_mapper = $self->get_mapper();
    unless ($current_mapper) {
	$status->set( 500, "Mapper requested for use before one is initialized" );
	return undef;	
    }
    
    return $current_mapper->map( $schema );
}

# Get the schema name for a schema, if it is mapped, it'll be located
# in the mapcache.
sub _get_schema_name {
    my $self = shift;
    my $schema = shift;

    return $self->cache( 'mapperh2m', $schema );
}

sub cache {
    my $self = shift;
    my ($map, $from, $to) = @_;

    my $cachename;
    if ($map eq 'mapperh2m') {
	$cachename = '_mapcacheh2m';
    } elsif ($map eq 'mapperm2h') {
	$cachename = '_mapcachem2h';	
    } elsif ($map eq 'temporal') {
	$cachename = '_temporalcache';
    } elsif ($map eq 'filter') {
	$cachename = '_filtercache';
    } elsif ($map eq 'hasauthschema') {
	$cachename = '_hasauthschema';
    } elsif ($map eq 'authschemaname') {
	$cachename = '_authschemaname';
    } elsif ($map eq 'authbindings') {
	$cachename = $map;
    } else {
	Yggdrasil::fatal( "Unknown cache type '$map' requested for populating" );
    }

    $self->{cache}->{$cachename}->{$from} = $to if $to;
    return $self->{cache}->{$cachename}->{$from};
}

sub cache_is_populated {
    my $self = shift;

    if (keys %{$self->{cache}->{_hasauthschema}}) {
	return 1;
    } else {
	return;
    }
}

# Map string like "Instances:Auth" to "Storage_auth_Instances" f.ex.
sub _get_auth_schema_name {
    my $self = shift;
    my $schema = shift;
    return $self->cache( 'authschemaname', $schema ) if 
      $self->cache( 'authschemaname', $schema );
    
    my @parts = split( ":", $schema );
    pop @parts; # remove the ":Auth" part
    my $usertable = join(":", @parts);

    my $ret = $self->_fetch( $self->get_structure( 'authschema' ) => 
			     { 
			      return => 'authtable',
			      where  => [ usertable => $usertable ],
			     } );

    my $at = $ret->[0]->{authtable};
    $self->cache( 'authschemaname', $schema, $at );
    return $at;
}


sub set_auth {
    my $self   = shift;
    my $schema = shift;
    my $action = shift;
    my $restrictions = shift;

    my $authschema = $self->{structure}->construct_userauth_from_schema( $schema );
    my $realschema = $self->_get_schema_name( $schema ) || $schema;

    if( $restrictions ) {
	for( my $i=0; $i<@$restrictions; $i+=2 ) {
	    my $authschema_binding    = $restrictions->[$i];
	    my $authschema_constraint = $restrictions->[$i+1];

	    # Change Foo:Auth, :Auth etc. to the real auth table
	    my $real_auth_schema = $authschema_binding;
	    if( $authschema_binding eq ":Auth" ) {
		$real_auth_schema = $authschema;
	    } elsif( $authschema_binding =~ /:Auth$/ ) {
		$real_auth_schema = $self->_get_auth_schema_name( $authschema_binding );
	    }

	    # Should real_auth_schema be mapped?
	    my $mapped = $self->_get_schema_name( $real_auth_schema );
	    $real_auth_schema = $mapped if $mapped;

	    $restrictions->[$i] = $real_auth_schema;

	    # Change schema references to this schema if it is mapped
	    # (so that the structure references the mapped and the
	    # engine actually finds the schema)
	    my $where = $authschema_constraint->{where};
	    next unless ref $where;

	    for( my $f=0; $f<@$where; $f+=2 ) {
		my $field = $where->[$f];
		my $value = $where->[$f+1];
		next unless ref $value eq "SCALAR";

		my( $schemaref, $schemafield ) = split m/\./, $$value;

		# If value does not contain a ".", then it's not a
		# schema reference, but should be a field reference.
		# Check if the field exists
		# FIX actually check if field exists
		unless( defined $schemafield ) {
		    next;
		}

		# Here we should be working with a schema reference
		if( $schemaref eq $schema ) {
		    # if these are ne, it means that the schema is mapped
		    if( $schema ne $realschema ) {
			my $mapped_schema = join(".", $realschema, $schemafield);
			$where->[$f+1] = \$mapped_schema;
		    }

		    next;
		}

		# This is just for consistency checking - it has no
		# effect other than occationally dying.
		my @matches = $self->_find_schema_by_name_or_alias( $schemaref, $restrictions );

		if( @matches > 1 ) {
		    die "'$schemaref' is mentioned more than once in the definition of $schema\n";
		}
		
		if( @matches == 0 ) {
		    die "'$schemaref' is never mentioned in the definition of $schema\n";
		}
	    }
	}

	my @mapped = $self->_map_fetch_schema_references( @$restrictions );
	$restrictions = \@mapped;
    }

    my $bindings = $restrictions ? Storable::nfreeze( $restrictions ) : undef;
    my $schemaname = $self->{structure}->get( 'authschema' );
    my $tick = $self->tick( 'store', $schemaname );
    $self->_store( $schemaname, 
		   key => [ qw/usertable authtable type/ ],
		   fields => {
			      usertable => $realschema,
			      authtable => $authschema,
			      type      => $action,
			      bindings  => $bindings,
			      tick      => $tick,
			     } );
}

sub is_valid_type {
    my $self = shift;
    
    return $self->{type}->is_valid_type( @_ );
}

sub get_defined_types {
    my $self = shift;
    
    return $self->{type}->valid_types();
}

# Checks and verifies a type, doesn't handle SET yet.  Returns the
# default of 'TEXT' if the type is undefined.
sub _check_valid_type {
    my $self = shift;
    my $type = shift;
    my $size;

    return 'TEXT' unless $type;
    
    $size = $1 if $type =~ s/\(\d+\)$//;

    my $status = $self->get_status();
    unless ($self->{type}->is_valid_type( $type )) {
	$status->set( 406, "Unknown type '$type'" );
	return undef;
    }
    
    if (defined $size) {
	if ($size < 1 || $size > $self->{type}->is_valid_type( $type )) {
	    $type = "$type(" . $self->{type}->is_valid_type( $type ) . ")";
	} else {
	    $type = "$type($size)";
	    } 
    } elsif ($type eq 'VARCHAR') {
	$type = "$type(255)";
    } 
    return $type;
}

# Ask if a schema is temporal.  Schema presumed to be mapped, or a
# schema which had nomap set.
sub _schema_is_temporal {
    my $self   = shift;
    my $schema = shift;

    return $self->cache( 'temporal', $schema );
}

sub _storage_path {
    my $self = shift;
    
    my $file = join('.', join('/', split '::', __PACKAGE__), "pm" );
    my $path = $INC{$file};
    $path =~ s/\.pm$//;
    return $path;
}

sub set_mapper {
    my $self = shift;
    my $mappername = shift;

    $self->{mapper} = Storage::Mapper->new( mapper => $mappername, status => $self->get_status() );
    return $self->{mapper};
}

sub get_mapper {
    my $self = shift;
    my $mappername = shift;

    return $self->{mapper};
}

sub get_structure {
    my $self = shift;
    my $structure = shift;

    return $self->{structure}->get( $structure );
}

sub prefix {
    my $self = shift;
    return $self->{structure}->internal( 'prefix' );
}

# Admin interface, not for normal use.

# Require the "admin" parameter to Storage to be set to a true value to access any admin method.
sub _admin_verify {
    my $self = shift;
    die( "Administrative interface unavailable without explicit request." )
      unless $self->{user}->is_a_member_of( 'admin' );
}

# Returns a list of all the structures, guarantees nothing about the order.
sub _admin_list_structures {
    my $self = shift;

    $self->_admin_verify();
    return $self->_list_structures();
}

sub _admin_dump_structure {
    my $self = shift;
    $self->_admin_verify();

    return $self->_dump_structure( @_ );
}

# Delete a named structure.
sub _admin_delete_structure {
    my $self = shift;

    $self->_admin_verify();
    $self->_delete_structure( @_ );
}

# Truncate a named structure.
sub _admin_truncate_structure {
    my $self = shift;

    $self->_admin_verify();
    $self->_truncate_structure( @_ );
}

1;
