package Yggdrasil::Storage;

use strict;
use warnings;

use Carp;

use Digest::MD5 qw(md5_hex);

our $storage;
our $STORAGEMAPPER   = 'Storage_mapname';
our $STORAGETEMPORAL = 'Storage_temporals';
our $STORAGECONFIG   = 'Storage_config';
our $MAPPER          = 'md5';

our %TYPES = (
	      TEXT    => 1,
	      VARCHAR => 255,
	      BOOLEAN => 1,
	      SET     => 1,
	      INTEGER => 1,
	      FLOAT   => 1,
	      DATE    => 1,
	      SERIAL  => 1,
	     );

sub new {
  my $class = shift;
  my $self  = {};
  my %data = @_;

  return $storage if $storage;

  my $engine = join(".", $data{engine}, "pm" );

  my $file = join('.', join('/', split '::', __PACKAGE__), "pm" );
  my $path = $INC{$file};
  $path =~ s/\.pm//;
  opendir( my $dh, $path ) || die "Unable to open $path: $!\n";
  my( $db ) = grep { $_ eq  $engine } readdir $dh;
  closedir $dh;
  
  
  if( $db ) {
    $db =~ s/\.pm//;
    my $engine_class = join("::", __PACKAGE__, $db );
    eval qq( require $engine_class );
    die $@ if $@;
    #  $class->import();
    $storage = $engine_class->new(@_);

    $storage->{logger} = Yggdrasil::get_logger( ref $storage );

    $storage->_initialize_config();
    
    $storage->_initialize_mapper();
    $storage->_initialize_temporal();

    return $storage;
  }
}

# define( Schema',
#         fields   => { field1, 
#                               { null => BOOL(0), type => type(TEXT), constraint => constraint(undef) }
#                       field2, 
#                               { null => BOOL(0), type => type(TEXT), constraint => constraint(undef) } },
#         temporal => BOOL(0),
#         nomap => BOOL(0) );

sub define {
    my $self = shift;
    my $schema = shift;

    my %data = @_;
    my $originalname = $schema;

    for my $fieldhash (values %{$data{fields}}) {	
	my $type = uc $fieldhash->{type};
	if ($type eq 'SERIAL' && $fieldhash->{null}) {
	    $fieldhash->{null} = 0;
	    $self->{logger}->warn( "Serial fields cannot allow unset values, overriding request." );
	}
	$fieldhash->{type} = $self->_check_valid_type( $type );
    }

    $schema = $self->_map_schema_name( $schema ) unless $data{nomap};

    return if $self->_structure_exists( $schema );

    my $retval = $self->_define( $schema, @_ );

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


# store ( schema, key => id, fields => { fieldname => value, fieldname2 => value2 })
sub store {
    my $self = shift;
    my $schema = shift;
    
    return $self->_store( $self->_get_schema_name( $schema ), @_ );
}

# fetch ( schema1 { return => [ fieldnames ], where => { s1field => s1value }, operator => operator }
#         schema2 { return => [ fieldnames ], where => { s2field => s2value }, operator => operator }
# We remap the schema names (the non-reference parameters here
sub fetch {
    my $self = shift;
    $self->{logger}->warn( "fetch( @_ )" );
   
    return $self->_fetch( map { ref()?$_:$self->_get_schema_name( $_ ) } @_ );
}

# exists ( schema, field, value ) 
sub exists :method {
    my $self = shift;
    my $schema = shift;

    $schema = $self->_get_schema_name( $schema );
    
    return undef unless $self->_structure_exists( $schema );
    return $self->fetch( $schema, { return => '*', where => { @_ } });
}

# entities, returns all the entities known to Yggdrasil.
sub entities {
    my $self = shift;
    my $aref = $self->fetch( 'MetaEntity', { return => 'entity' } );

    return map { $_->{entity} } @$aref;
}

sub relations {
    my $self = shift;
    my $aref = $self->fetch( 'MetaRelation', { return => 'relation' });

    return map { $_->{relation} } @$aref;
}

# Map structure names into a given hash, this is done to allow usage
# of any name into a schema name, character sets and reserved words
# are no constraints.
sub _map_schema_name {
    my $self = shift;
    my $schema = shift;

    confess "no schema" unless $schema;

    my $digest = md5_hex( $schema );
    $digest =~ y/0-9a-f/a-p/;

    return $digest;
}

# Get the schema name for a schema, if it is mapped, it'll be located
# in the mapcache, if not it'll be passed along without intervention.
sub _get_schema_name {
    my $self = shift;
    my $schema = shift;

    return $self->{_mapcacheh2m}->{$schema} || $schema;
}

# Checks and verifies a type, doesn't handle SET yet.  Returns the
# default of 'TEXT' if the type is undefined.
sub _check_valid_type {
    my $self = shift;
    my $type = shift;
    my $size;

    return 'TEXT' unless $type;
    
    $size = $1 if $type =~ s/\(\d+\)$//;
    confess "Unknown type '$type'" unless $TYPES{$type};
    
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
#	    $MAPPER          = $value if lc $key eq 'mapper' && $self->_valid_mapper( $value );
	}
    } else {
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

	$self->store( $STORAGECONFIG, key => "id",
		      fields => { id => 'mapper', value => $MAPPER });
    }
}

1;
