package Yggdrasil::Storage;

use strict;
use warnings;

use Yggdrasil::Storage::Mapper;

our $STORAGEMAPPER   = 'Storage_mapname';
our $STORAGETEMPORAL = 'Storage_temporals';
our $STORAGECONFIG   = 'Storage_config';
our $STORAGETICKER   = 'Storage_ticker';
our $MAPPER;

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
	
	unless (defined $storage) {
	    $status->set( 500 );
	    return undef;
	}
      
	$storage->{bootstrap} = $data{bootstrap};

	$storage->{auth}   = $data{auth};
	$storage->{status} = $status;

	$MAPPER = $data{mapper};
	$ADMIN  = $data{admin};
	
	$storage->{logger} = Yggdrasil::get_logger( ref $storage );

	if( ! $storage->{bootstrap} && $storage->yggdrasil_is_empty() ) {
	    $status->set( 503, "Yggdrasil has not been bootstrapped" );
	    return;
	}
	
	$storage->_initialize_config();
	$storage->_initialize_mapper();
	$storage->_initialize_ticker();
	$storage->_initialize_temporal();
	
	return $storage;
    }
}
  
sub get_status {
    my $self = shift;
    return $self->{status};
}

# define( Schema',
#         fields   => { field1, 
#                               { null => BOOL(0), type => type(TEXT),
#                                 index => BOOL(0), constraint => constraint(undef) }
#                       field2, 
#                               { null => BOOL(0), type => type(TEXT), 
#                                 index => BOOL(0), constraint => constraint(undef) }
#         temporal => BOOL(0),
#         nomap => BOOL(0),
#         hints => { field1 => { foreign => 'Schema', index => [1|0] }}
# );
sub define {
    my $self = shift;
    my $schema = shift;

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
	$data{hints}->{start}  = { foreign => $STORAGETICKER };
	$data{hints}->{stop}   = { foreign => $STORAGETICKER };
    } else {
	# Add commiter field
	$data{fields}->{committer} = { type => 'VARCHAR(255)', null => 0 };
    }

    my $retval = $self->_define( $schema, %data );

   # We might create a schema with name "0", so check for a defined value.
    if (defined $retval) {
	unless ($data{nomap}) {
	    $self->{logger}->warn( "Remapping $originalname to $schema." );	
	    $self->{_mapcacheh2m}->{$originalname} = $schema;
	    $self->{_mapcachem2h}->{$schema} = $originalname;
	    $self->store( $STORAGEMAPPER, key => "humanname",
			  fields => { humanname => $originalname, mappedname => $schema });
	}
	if ($data{temporal}) {
	    $self->{_temporalcache}->{$schema} = 1;
	    $self->store( $STORAGETEMPORAL, key => "tablename",
			  fields => { tablename => $schema, temporal => 1 });
	}
    }
    
    return $retval;
}

# store ( schema, key => id|[f1,f2...], fields => { fieldname => value, fieldname2 => value2 })
sub store {
    my $self = shift;
    my $schema = shift;
    my %params = @_;

    my $status = $self->get_status();

    my $uname;
    if( $self->{bootstrap} ) {
	$uname = "bootstrap";
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
    my $real_schema = $self->_get_schema_name( $schema );
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

	$self->_expire( $real_schema, $tick, %keys );
    }

    return $self->_store( $real_schema, tick => $tick, %params );
}

sub tick {
    my $self = shift;

    my $c;
    if( $self->{bootstrap} ) {
	$c = 'bootstrap'
    } else {
	$c = $self->{user}->id();
    }
    
    return $self->_store( $self->_get_schema_name($STORAGETICKER), fields => { committer => $c } );
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
	$fetchref = $self->fetch( 'Storage_ticker', { return => [ 'id', 'stamp', 'committer' ],
						      where  => [ 'stamp' => \qq<$from> ],
						      operator => '=',
						    } );
    }

    my @hits;
    for my $tick (@$fetchref) {
	push @hits, $tick;
    }
    return @hits;
}

sub raw_store {
    my $self = shift;
    my $schema = shift;
    $self->_admin_verify();
    
    return $self->_raw_store( $self->_get_schema_name( $schema ), @_ );
}

# fetch ( schema1, { return => [ fieldnames ], where => [ s1field1 => s1value1, ... ], operator => operator, bind => bind-op }
#         schema2, { return => [ fieldnames ], where => [ s2field => s2value, ... ], operator => operator, bind => bind-op }
#         { start => $start, stop => $stop } (optional)
# We remap the schema names (the non-reference parameters) here.
sub fetch {
    my $self = shift;
    my @targets;
    
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
    for( my $i=0; $i < @_; $i += 2 ) {
	my( $schema, $queryref ) = ($_[$i], $_[$i+1]);
	next unless $queryref->{join} || $queryref->{as};
	$queryref->{as} = $schema;
	push @targets, $schema;
    }

    unless ($self->{bootstrap}) {
	my %params = @_;
	if (! $self->can( operation => 'readable', data => \%params, targets => \@targets )) {
	    my $status = $self->get_status();
	    $status->set( 403 );
	    return;
	} 
    }

    return $self->_fetch( map { ref()?$_:$self->_get_schema_name( $_ ) } @_, $time );
}

# Ask Auth if an action can be performed on a target.  Returns true / false.
sub can {
    my $self = shift;

    return $self->{auth}->can( @_ );
}

sub raw_fetch {
    my $self = shift;
    $self->_admin_verify();
    
    return $self->_raw_fetch( map { ref()?$_:$self->_get_schema_name( $_ ) } @_ );
}

# expire ( $schema, $indexfield, $key )
sub expire {
    my $self   = shift;
    my $schema = shift;
    
    my $real_schema = $self->_get_schema_name( $schema );
    return unless $self->_schema_is_temporal($real_schema);

    # Tick
    my $tick = $self->tick();

    $self->_expire( $real_schema, $tick, @_ );
}

# exists ( schema, field, value ) 
sub exists :method {
    my $self = shift;
    my $schema = shift;

    $schema = $self->_get_schema_name( $schema );
    
    return undef unless $self->_structure_exists( $schema );
    return $self->fetch( $schema, { return => '*', where => [ @_ ] });
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

    unless ($MAPPER) {
	$status->set( 500, "Mapper requested for use before one is initialized" );
	return undef;	
    }
    
    return $MAPPER->map( $schema );
}

# Get the schema name for a schema, if it is mapped, it'll be located
# in the mapcache, if not it'll be passed along without intervention.
sub _get_schema_name {
    my $self = shift;
    my $schema = shift;

    return $self->{_mapcacheh2m}->{$schema} || $schema;
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

    return $self->{_temporalcache}->{$schema};
}

# Initalize the mapper cache and, if needed, the schema to store schema
# name mappings.
sub _initialize_mapper {
    my $self = shift;
    
    if ($self->_structure_exists( $STORAGEMAPPER )) {
	# Populate map cache from existing storagemapper.	
	my $listref = $self->fetch( $STORAGEMAPPER, { return => '*' } );
	
	for my $mappair (@$listref) {
	    my ( $human, $mapped ) = ( $mappair->{humanname}, $mappair->{mappedname} );
	    $self->{_mapcacheh2m}->{$human}  = $mapped;
	    $self->{_mapcachem2h}->{$mapped} = $human;
	}
    } else {
	$self->define( $STORAGEMAPPER,
		       nomap  => 1,
		       fields => {
				  humanname  => { type => 'TEXT' },
				  mappedname => { type => 'TEXT' },
				 },
		     );
    }
}

# Initalize and cache what schemas are temporal, created required
# schemas if needed.
sub _initialize_temporal {
    my $self = shift;

    if ($self->_structure_exists( $STORAGETEMPORAL )) {
	my $listref = $self->fetch( $STORAGETEMPORAL, { return => '*' });
	for my $temporalpair (@$listref) {
	    my ($table, $temporal) = ( $temporalpair->{tablename}, $temporalpair->{temporal} );
	    $self->{_temporalcache}->{$table} = $temporal;
	}
    } else {
	$self->define( $STORAGETEMPORAL, 
		       nomap  => 1,
		       fields => {
				  tablename => { type => 'TEXT' },
				  temporal  => { type => 'BOOLEAN' },
				 },
		     );
    }
    
}

sub _initialize_ticker {
    my $self = shift;

    unless( $self->_structure_exists($STORAGETICKER) ) {
	$self->define( $STORAGETICKER,
		       nomap  => 1,
		       fields => {
			   id    => { type => 'SERIAL' },
			   stamp => { type => 'TIMESTAMP', 
				      null => 0,
				      default => "current_timestamp" },
		       }, );
    }
}

# Initialize the STORAGE config, this structure is required to be
# accessible with the specific configuration for this
# Yggdrasil::Storage instance and its workings.  TODO, fix mapper setup.
sub _initialize_config {
    my $self = shift;

    if ($self->_structure_exists( $STORAGECONFIG )) {
	my $listref = $self->fetch( $STORAGECONFIG, { return => '*' });
	for my $temporalpair (@$listref) {
	    my ($key, $value) = ( $temporalpair->{id}, $temporalpair->{value} );
	    
	    $STORAGEMAPPER   = $value if lc $key eq 'mapstruct' && $value && $value =~ /^Storage_/;
	    $STORAGETEMPORAL = $value if lc $key eq 'temporalstruct' && $value && $value =~ /^Storage_/;

	    if (lc $key eq 'mapper') {
		$self->{logger}->warn( "Ignoring request to use $MAPPER as the mapper, the Storage requires $value" ) if $MAPPER && $MAPPER ne $value;
		$MAPPER = $self->set_mapper( $value );
		return undef unless $MAPPER;
	    }
	    
	}
    } else {
	if ($MAPPER) {
	    my $mappername = $MAPPER;
	    $MAPPER = $self->set_mapper( $mappername );
	    return undef unless $MAPPER;

	} else {
	    $MAPPER = $self->get_default_mapper();
	}
	
	$self->define( $STORAGECONFIG, 
		       nomap  => 1,
		       fields => {
				  id    => { type => 'TEXT' },
				  value => { type => 'TEXT' },
				 },
		     );
	$self->store( $STORAGECONFIG, key => "id",
		      fields => { id => 'mapstruct', value => $STORAGEMAPPER });
	$self->store( $STORAGECONFIG, key => "id",
		      fields => { id => 'temporalstruct', value => $STORAGETEMPORAL });


	my $mappername = ref $MAPPER;
	$mappername =~ s/.*::(.*)$/$1/;
	$self->store( $STORAGECONFIG, key => "id",
		      fields => { id => 'mapper', value => $mappername });
    }    
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
    
    return Yggdrasil::Storage::Mapper->new( mapper => $mappername, status => $self->get_status() );
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
