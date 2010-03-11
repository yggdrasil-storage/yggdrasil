package Yggdrasil::Storage;

use strict;
use warnings;

use Storable qw();

use Yggdrasil::Transaction;
use Yggdrasil::Storage::Mapper;
use Yggdrasil::Storage::Structure;

use Yggdrasil::Storage::Auth::User;
use Yggdrasil::Storage::Auth::Role;

our $TRANSACTION = Yggdrasil::Transaction->create_singleton();

our $ADMIN = undef;

our %TYPES = (
    TEXT      => 1,
    VARCHAR   => 255,
    BOOLEAN   => 1,
    SET       => 1,
    INTEGER   => 1,
    FLOAT     => 1,
    TIMESTAMP => 1,
    DATE      => 1,
    SERIAL    => 1,
    BINARY    => 1,
    PASSWORD  => 1,
	     );

sub new {
    my $class = shift;
    my $self  = {};
    my %data = @_;
    
    my $status = $self->{status} = $data{status};

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
	$storage->{bootstrap} = $data{bootstrap};
	$storage->{transaction} = $TRANSACTION;
	
	unless (defined $storage) {
	    $status->set( 500 );
	    return undef;
	}

	$storage->{status} = $status;

	$storage->{mapper} = $data{mapper};
	$ADMIN  = $data{admin};
	
	$storage->{logger} = Yggdrasil::get_logger( ref $storage );

	# Structure the internals of Storage.  Creates structure if
	# needed, otherwise it's just read.
	$storage->{structure} = new Yggdrasil::Storage::Structure( storage => $storage );
	$storage->{structure}->init();
	
	$storage->_set_default_user("nobody");
	return $storage;
    }
}

sub _set_default_user {
    my $self = shift;
    my $user = shift;

    my $u = Yggdrasil::Storage::Auth::User->get_nobody( $self );
    $self->{user} = $u;
}

sub user {
    my $self = shift;

    return $self->{user};
}

sub bootstrap {
    my $self  = shift;
    my %users = @_;

    my $status = $self->{status};
    $self->{bootstrap} = 1;

    if( ! $self->{bootstrap} && $self->yggdrasil_is_empty() ) {
	$status->set( 503, "Yggdrasil has not been bootstrapped" );
	return;
    }

    # Create default users and roles
    my %roles;
    for my $role ( qw/admin user/ ) {
	my $r = Yggdrasil::Storage::Auth::Role->define( $self, $role );
	$roles{$role} = $r;
    }

    # create nobody
    my $nobody_role = Yggdrasil::Storage::Auth::Role->define( $self, "nobody" );
    my $nobody_user = Yggdrasil::Storage::Auth::User->define( $self, "nobody", undef );
    $nobody_role->add( $nobody_user );
    $nobody_role->grant( $self->get_structure( 'authuser' ) => 'r',
			 id => $nobody_user->id() );

    my %usermap;
    for my $user ( "root", (getpwuid( $> ) || "default"), keys %users ) {
	my $pwd = $users{$user};
	$pwd ||= $self->_generate_password();

	my $u = Yggdrasil::Storage::Auth::User->define( $self, $user, $pwd );

	for my $rolename ( keys %roles ) {
	    my $role = $roles{$rolename};
	    $role->add( $u );
	    $role->grant( $self->get_structure( 'authuser' ) => 'm', 
			  id => $u->id() );

	    $nobody_role->grant( $self->get_structure( 'authuser' ) => 'r', 
				 id => $u->id() );

	}

	$self->{user} = $u if $user eq "root";
	$usermap{$user} = $pwd;
    }

    return %usermap;
}

sub _generate_password {
    my $self = shift;
    my $randomdevice = "/dev/urandom";
    my $pwd_length = 12;
    
    my $password = "";
    my $randdev;
    open( $randdev, $randomdevice ) 
	|| die "Unable to open random device $randdev: $!\n";
    until( length($password) == $pwd_length ) {
        my $byte = getc $randdev;
        $password .= $byte if $byte =~ /[a-z0-9]/i;
    }
    close $randdev;

    return $password;
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

    unless ($self->{bootstrap}) {
	my( $parent ) = $schema =~ /^(.*)::/ || "UNIVERSAL";
	if (! $self->can( operation => 'define', targets => [ $parent ] )) {
	    $status->set( 403, "You are not permitted to create the structure '$schema' under '$parent'." );
	    return;
	} 
    }
    
    for my $fieldhash (values %{$data{fields}}) {	
	my $type = uc $fieldhash->{type};
	if ($type eq 'SERIAL' && $fieldhash->{null}) {
	    $fieldhash->{null} = 0;
	    $self->{logger}->warn( "Serial fields cannot allow unset values, overriding request." );
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
	# Add commiter field
	$data{fields}->{committer} = { type => 'VARCHAR(255)', null => 0 };
    }

    $transaction->log( "Defined $originalname" );
    my $retval = $self->_define( $schema, %data );

    if ($retval) {
	unless ($data{nomap}) {
	    $self->{logger}->warn( "Remapping $originalname to $schema." );
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
	    $self->{structure}->_define_auth( $schema, $originalname, $data{auth}, $data{nomap} );
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

    my $uname;
    if( $self->{bootstrap} ) {
	$uname = $self->{user}?$self->{user}->id():'bootstrap';
    } else {
	$uname = $self->{user}->id();
    }

    unless ($self->{bootstrap}) {
	if (! $self->can( operation => 'store', targets => [ $schema ], data => \%params )) {
	    $status->set( 403 );
	    return;
	} 
    }

    # Check if we already have the value
    my $real_schema = $self->_get_schema_name( $schema ) || $schema;
    my $aref = $self->fetch( $real_schema => { where => [ %{$params{fields}} ] } );
    if( @$aref ) {
	$status->set( 202, "Value(s) already set" );
	return 1;
    }

    # Tick
    my $tick;
    if( $self->_schema_is_temporal($real_schema) ) {
	# tick when we commit changes to temporal tables
	$tick = $self->tick();
    } else {
	# don't tick, but add committer instead
	$params{fields}->{committer} = $uname;
    }


    # Expire the old value
    my %keys;
    my $key = $params{key};
    if( $key ) {
	if( ref $key eq 'ARRAY' ) {
	    for my $k (@$key) {
		$keys{$k} = $params{fields}->{$k};
	    }
	} else {
	    $keys{$key} = $params{fields}->{$key};
	}

	$transaction->log( "Expire: $schema " . join( ", ", map { defined()?$_:"" } %keys ) );
	$self->_expire( $real_schema, $tick, %keys );
    }

    $transaction->log( "Store: $schema " . join( ", ", map { defined()?$_:"" } %keys ) );
    $transaction->commit();    
    my $r = $self->_store( $real_schema, tick => $tick, %params );
    my $user = $self->user();
    
    if ($user) {	
	for my $role ( $user->member_of() ) {	    
	    $role->grant( $real_schema => 'm', id => $r );
	}
    }    

    return $r;

}

sub tick {
    my $self = shift;

    my $c;
    if( $self->{bootstrap} ) {
	$c = 'bootstrap'
    } else {
	$c = $self->{user}->id();
    }
    
    my $schema = $self->_get_schema_name($self->get_structure( 'ticker' )) || $self->get_structure( 'ticker' );
    return $self->_store( $schema, fields => { committer => $c } );
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
    unless ($self->{bootstrap}) {
	# Add auth bindings to query
	my @authdefs = $self->_add_auth( "fetch", @schemadefs );
	push( @schemadefs, @authdefs );
    }

    # map schema names
    @schemadefs = $self->_map_fetch_schema_references( @schemadefs );

    my $ref = $self->_fetch( @schemadefs, $time );
    $transaction->commit();
    return $ref;
}

sub _add_auth {
    my $self = shift;
    my $authtype = shift;
    my @schemadefs = @_;
    
    my @authdefs;
    for( my $i=0; $i<@schemadefs; $i+=2 ) {
	my $schema = $schemadefs[$i];
	my $schemabindings = $schemadefs[$i+1];

	# 1. Find auth-bindings for this schema
	my $ret = $self->_fetch( $self->get_structure( 'authschema' ) =>
				 {
				  return => 'bindings',
				  where  => [ usertable => $schema ]
				 } );
	next unless $ret;

	my $frozen_bindings = $ret->[0]->{bindings};
	my $bindings = Storable::thaw( $frozen_bindings );

	# 2. What auth-bindings to apply (Fetch/Create/Expire etc.)
	my $typebindings = $bindings->{$authtype};
	next unless $typebindings;

	# 3. Find any references (\q<>) in the bindings to this schema
	my @membership;
	for( my $j=0; $j<@$typebindings; $j+=2 ) {
	    my $authschema = $typebindings->[$j];
	    my $authconstraint = $typebindings->[$j+1];

	    my $where = $authconstraint->{where};
	    next unless $where;

	    for( my $k=1; $k<@$where; $k+=2 ) {
		next unless ref $where->[$k] eq "SCALAR";
		my $ref = $where->[$k];
		my $value = $$ref;

		my( $target, $field ) = split m/\./, $value;
		next unless $target eq $schema;

		if( $schemabindings->{alias} ) {
		    $target = $schemabindings->{alias};
		    $value = join(".", $target, $field);
		    $where->[$k] = \$value;
		}
	    }

	    my $alias = $authconstraint->{alias};
	    my $member = {
			  where => [
				    userid => $self->user()->id(),
				    roleid => \qq<$alias.roleid>,
				   ]
			 };

	    push( @membership, $self->get_structure( 'authmember' ), $member );
						    
	}

	push( @authdefs, @$typebindings, @membership );
    }

    return @authdefs;
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
    
    my ($user, $pass, $session) = ($params{'user'}, $params{'password'}, $params{'session'});

    my $status = $self->get_status();
    my $user_obj;

    if (defined $user && defined $pass) {
	# Otherwise, we got both a username and a password.
	$user_obj = Yggdrasil::Storage::Auth::User->get( $self, $user );

	if( $user_obj ) {
	    my $realpass = $user_obj->password() || '';

	    if (! defined $pass || $pass ne $realpass) {
		$user_obj = undef;
	    }
	}
	$session = undef;
    } elsif ($session) {
	# Lastly, we got a session id - see if we find a user with this session id
	# $user_obj = Yggdrasil::User->get_with_session( yggdrasil => $self, session => $session );
    } elsif (-t && ! defined $user && ! defined $pass) {
	# First, let see if we're connected to a tty without getting a
	# username / password, at which point we're already authenticated
	# and we don't want to touch the session.  $> is effective UID.
	my $uname = (getpwuid($>))[0];
	$user_obj = Yggdrasil::Storage::Auth::User->get( $self, $uname );
	$session = "invalid";
    }

    if( $user_obj ) {
	$self->{user} = $user_obj;
	#unless( $session ) {
	#    $session = md5_hex(time() * $$ * rand(time() + $$));
	#    $user_obj->session( $session );
	#}
	#$self->{session} = $session;
	$status->set( 200 );
    } else {
	$status->set( 403 );
    }

    return $user_obj;
}


# Ask Auth if an action can be performed on a target.  Returns true / false.
sub can {
    my $self = shift;

    return 1;
#    return $self->{auth}->can( @_ );
}

sub raw_fetch {
    my $self = shift;
    $self->_admin_verify();
    
    my @mapped_def = $self->_map_fetch_schema_references( @_ );

    return $self->_raw_fetch( @mapped_def );
}

# expire ( $schema, $indexfield, $key )
sub expire {
    my $self   = shift;
    my $schema = shift;
    
    my $real_schema = $self->_get_schema_name( $schema ) || $schema;
    return unless $self->_schema_is_temporal($real_schema);

    # Tick
    my $tick = $self->tick();

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
    } else {
	Yggdrasil::fatal( "Unknown cache type '$map' requested for populating" );
    }

    $self->{$cachename}->{$from} = $to if $to;
    return $self->{$cachename}->{$from};
}

# Map string like "Instances:Auth" to "Storage_auth_Instances" f.ex.
sub _get_auth_schema_name {
    my $self = shift;
    my $schema = shift;

    my @parts = split( ":", $schema );
    pop @parts; # remove the ":Auth" part
    my $usertable = join(":", @parts);

    my $ret = $self->_fetch( $self->get_structure( 'authschema' ) => 
			     { 
			      return => 'authtable',
			      where  => [ usertable => $usertable ],
			     } );
    
    return $ret->[0]->{authtable};
}

sub get_defined_types {
    return keys %TYPES;
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
    unless ($TYPES{$type}) {
	$status->set( 406, "Unknown type '$type'" );
	return undef;
    }
    
    if (defined $size) {
	if ($size < 1 || $size > $TYPES{$type}) {
	    $type = "$type(" . $TYPES{$type} . ")";
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

    $self->{mapper} = Yggdrasil::Storage::Mapper->new( mapper => $mappername, status => $self->get_status() );
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
    die( "Administrative interface unavailable without explicit request." ) unless $ADMIN;
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
