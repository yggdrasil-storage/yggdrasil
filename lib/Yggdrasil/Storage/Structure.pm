package Yggdrasil::Storage::Structure;

use strict;
use warnings;

sub new {
    my $class  = shift;
    my %params = @_;
    
    my $self = {
		mapper      => 'mapname',
		temporal    => 'temporals',
		filter      => 'filter',
		config      => 'config',
		ticker      => 'ticker',
		authschema  => 'authschema',
		authuser    => 'auth_user',
		authrole    => 'auth_role',
		authmember  => 'auth_membership',

		_prefix     => 'Storage_',
		_storage    => $params{storage},
		_userfields => {
				authuser => {
					     fullname => 'TEXT',
					     password => 'TEXT',
					     cert     => 'BINARY',
					     session  => 'TEXT',
					    },
				authrole => {
					     description => 'TEXT',
					    },
			       },
		_filter     => {
				authuser => {
					     password => [ sha => 256 ],
					    }
			       },
	       };
    
    bless $self, $class;

    return $self;
}

sub init {
    my $self = shift;
    
    $self->_initialize_config();
    $self->_initialize_filter();
    $self->_initialize_mapper();
    $self->_initialize_ticker();
    $self->_initialize_temporal();
    $self->_initialize_auth();
    $self->_initialize_fields();
}

sub get {
    my $self = shift;
    return $self->_getter_setter( @_ );
}

sub internal {
    my $self = shift;
    my $key  = shift;
    return $self->_getter_setter( "_$key" );
}

sub set {
    my $self = shift;
    return $self->_getter_setter( @_ );
}

sub _getter_setter {
    my $self = shift;
    my ($key, $value) = @_;
    my $prop;
    
    my $structure;
    if ($key =~ /^(.*):(.*)/) {
	$key  = $1;
	$prop = $2;
	$structure = $self->internal( 'prefix' ) . $self->{$key};
    } elsif ($key !~ /^_/) {
	# The key didn't get accessed via internal(), that means we
	# want a structure, and that means we need to add the storage
	# prefix to the key.
	$structure = $self->internal( 'prefix' ) . $key;
    } else {
	$structure = $self->{$key};	
    }

    Yggdrasil::fatal( "Unknown structure '$key' requested" ) unless $structure;

    if ($prop) {
	my $fieldhash = $self->internal( 'userfields' );
	Yggdrasil::fatal( "Access to internal structure failed" ) unless $fieldhash->{$key}->{$prop};
	return $structure . '_' . $prop if $prop;
    }
    
    $self->{$key} = $value if $value;
    return $structure;
}

sub _initialize_auth {
    my $self = shift;

    $self->_initialize_schema_auth();
    $self->_initialize_user_auth();
}

# Initalize the mapper cache and, if needed, the schema to store schema
# name mappings.
sub _initialize_mapper {
    my $self = shift;
    my $schema = $self->get( 'mapper' );
    
    if ($self->{_storage}->_structure_exists( $schema )) {
	# Populate map cache from existing storagemapper.	
	my $listref = $self->{_storage}->fetch( $schema, { return => '*' } );
	
	for my $mappair (@$listref) {
	    my ( $human, $mapped ) = ( $mappair->{humanname}, $mappair->{mappedname} );
	    $self->{_storage}->cache( 'mapperh2m', $human, $mapped );
	    $self->{_storage}->cache( 'mapperm2h', $mapped, $human );
	}
    } else {
	$self->{_storage}->define( $schema,
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
    my $schema = $self->get( 'temporal' );

    if ($self->{_storage}->_structure_exists( $schema )) {
	my $listref = $self->{_storage}->fetch( $schema, { return => '*' });
	for my $temporalpair (@$listref) {
	    my ($table, $temporal) = ( $temporalpair->{tablename}, $temporalpair->{temporal} );
	    $self->{_storage}->cache( 'temporal', $table, $temporal );
	}
    } else {
	$self->{_storage}->define( $schema, 
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
    my $schema = $self->get( 'ticker' );
    
    unless ( $self->{_storage}->_structure_exists( $schema ) ) {
	$self->{_storage}->define( $schema,
				  nomap  => 1,
				  fields => {
					     id    => { type => 'SERIAL' },
					     stamp => { type => 'TIMESTAMP', 
							null => 0,
							default => "current_timestamp" },
					    }, );
    }
}

sub _initialize_filter {
    my $self = shift;
    my $schema = $self->get( 'filter' );
    
    if ( $self->{_storage}->_structure_exists( $schema ) ) {
	my %schemafilters;
	my $listref = $self->{_storage}->fetch( $schema, { return => '*' });
	for my $f (@$listref) {
	    my ($schemaname, $filter, $field, $params) =
	      ( $f->{schemaname}, $f->{filter}, $f->{field}, $f->{params} );
	    # FIXME, verify filter existence.
	    push @{$schemafilters{$schemaname}},
	      { filter => $filter, field => $field, params => $params };
	}

	for my $schemaname (keys %schemafilters) {
	    $self->{_storage}->cache( 'filter', $schemaname, \@{$schemafilters{$schemaname}})
	}	
    } else {
	$self->{_storage}->define( $schema,
				   nomap  => 1,
				   fields => {
					      id         => { type => 'SERIAL' },
					      schemaname => { type => 'TEXT', null => 0 },
					      filter     => { type => 'TEXT', null => 0 },
					      field      => { type => 'TEXT', null => 0 },
					      params    => { type => 'TEXT', null => 0 },
					     }, );
	
    }
}

sub _initialize_user_auth {
    my $self = shift;
    my $userschema   = $self->get( 'authuser' );
    my $roleschema   = $self->get( 'authrole' );
    my $memberschema = $self->get( 'authmember' );
    
    unless ( $self->{_storage}->_structure_exists( $roleschema ) ) {
	$self->{_storage}->define( $roleschema,
				  nomap  => 1,
				  fields => {
					     id   => { type => 'SERIAL', null => 0 },
					     name => { type => 'TEXT', null => 0 },
					    },
				  auth => {
					   create =>
					   [
					    ':Auth' => {
							where => [ id  => \qq<$roleschema.id>,
								   'm' => 1 ],
						       },
					   ],
			   
					   fetch => 
					   [
					    ':Auth' => {
							where => [ id => \qq<$roleschema.id>,
								   r  => 1],
						       },
					   ],
			   
					   update => 
					   [
					    ':Auth' => {
							where => [ id => \qq<$roleschema.id>,
								   w  => 1 ],
						       },
					   ],

					   expire =>
					   [
					    ':Auth' => {
							where => [ id  => \qq<$roleschema.id>,
								   'm' => 1 ],
						       },
					   ],
					  } );
    }

    unless ( $self->{_storage}->_structure_exists( $userschema ) ) {
	$self->{_storage}->define( $userschema,
				  nomap  => 1,
				  temporal => 1,
				  fields => {
					     id       => { type => 'SERIAL', null => 0 },
					     name     => { type => 'TEXT', null => 0 },
					    },
				  auth => {
					   create =>
					   [
					    ':Auth' => {
							where => [ id  => \qq<$userschema.id>,
								   'm' => 1 ],
						       },
					   ],
			   
					   fetch => 
					   [
					    ':Auth' => {
							where => [ id => \qq<$userschema.id>,
								   r  => 1],
						       },
					   ],
			   
					   update => 
					   [
					    ':Auth' => {
							where => [ id => \qq<$userschema.id>,
								   w  => 1 ],
						       },
					   ],

					   expire =>
					   [
					    ':Auth' => {
							where => [ id  => \qq<$userschema.id>,
								   'm' => 1 ],
						       },
					   ],
					  } );
    }

    unless ( $self->{_storage}->_structure_exists($memberschema) ) {
	$self->{_storage}->define( $memberschema,
				  nomap  => 1,
				  fields => {
					     userid => { type => 'INTEGER', null => 0 },
					     roleid => { type => 'INTEGER', null => 0 },
					    },
				  temporal => 1,
				  nomap    => 1,
				  hints    => {
					       userid => { foreign => $userschema },
					       roleid => { foreign => $roleschema },
					      },
				  auth     => {
					       create => 
					       [
						qq<$roleschema:Auth> => 
						{
						 where => [ id  => \qq<$memberschema.roleid>,
							    'm' => 1 ],
						},
					       ],
					       fetch  => 
					       [
						qq<$roleschema:Auth> => 
						{
						 where => [ id => \qq<$memberschema.roleid>,
							    r  => 1, ],
						},
						qq<$userschema:Auth> =>
						{
						 where => [ id => \qq<$memberschema.userid>,
							    r  => 1, ],
						}
					       ],
					       update => undef,
					       expire => 
					       [
						qq<$roleschema:Auth> =>
						{
						 where => [ id  => \qq<$memberschema.roleid>,
							    'm' => 1, ],
						},
					       ]
					      } );
    
    }

}

# FIXME, permissions.  
sub _initialize_fields {
    my $self = shift;
    my $structhash = $self->internal( 'userfields' );

    for my $structure (keys %{$structhash}) {
	for my $fieldname (keys %{$structhash->{$structure}}) {
	    my $type = $structhash->{$structure}->{$fieldname};
	    my $schema = $self->get( "$structure:$fieldname" );
	    #	my $authrole = $self->get( 'authrole' );
	    my $filter = $self->internal( 'filter' )->{$structure}->{$fieldname};
	    my @filterfiller = ();
	    @filterfiller = ( filter => $filter ) if $filter;
	
	    unless ( $self->{_storage}->_structure_exists( $schema ) ) {
		$self->{_storage}->define( $schema,
					   temporal => 1,
					   nomap  => 1,
					   fields => {
						      id    => { type => 'INTEGER', null => 0 },
						      value => {
								type => $type,
								null => 0,
								@filterfiller,
							       },
						     },
					   hints  => { id => { foreign => $self->get( 'authuser' ) } },
# 				      auth => {
# 					       create =>
# 					       [
# 						':Auth' => {
# 							    where => [ id  => \qq<$schema.id>,
# 								       'm' => 1 ],
# 							   },						
# 					       ],
			   
# 					       fetch => 
# 					       [
# 						':Auth' => {
# 							    where => [ id => \qq<$schema.id>,
# 								       r  => 1],
# 							   },
# 						$authrole => {
# 							      where => 
# 							      }
# 									    },
						
# 					       ],
			   
# 					       update => 
# 					       [
# 						':Auth' => {
# 							    where => [ id => \qq<$schema.id>,
# 								       w  => 1 ],
# 							   },
# 					       ],
					       
# 					       expire =>
# 					       [
# 						':Auth' => {
# 							    where => [ id  => \qq<$schema.id>,
# 								       'm' => 1 ],
# 							   },
# 					       ],
# 					      }
					 );
	    }
	}
    }    
}

sub _initialize_schema_auth {
    my $self = shift;
    my $schema = $self->get( 'authschema' );
    
    unless ( $self->{_storage}->_structure_exists( $schema ) ) {
	$self->{_storage}->define( $schema,
				  nomap  => 1,
				  fields => {
					     usertable => { type => 'TEXT',
							    null => 0 },
					     authtable => { type => 'TEXT',
							    null => 0 },
					     bindings  => { type => 'BINARY' } } );
    }
}

# Initialize the STORAGE config, this structure is required to be
# accessible with the specific configuration for this
# Yggdrasil::Storage instance and its workings.  TODO, fix mapper setup.
sub _initialize_config {
    my $self = shift;

    my $schema = $self->get( 'config' );
    my $mapper_name = $self->{_storage}->get_mapper();
    if ($self->{_storage}->_structure_exists( $schema )) {
	my $listref = $self->{_storage}->fetch( $schema, { return => '*' });
	for my $temporalpair (@$listref) {
	    my ($key, $value) = ( $temporalpair->{id}, $temporalpair->{value} );
	    
	    $self->set( 'mapper', $value ) if lc $key eq 'mapstruct' && $value && $value =~ /^Storage_/;
	    $self->set( 'temporal', $value ) if lc $key eq 'temporalstruct' && $value && $value =~ /^Storage_/;

	    if (lc $key eq 'mapper') {
		my $logger = $self->{_storage}->{logger};
		$logger->warn( "Ignoring request to use $mapper_name as the mapper, the Storage requires $value" )
		  if $mapper_name && $mapper_name ne $value;
		my $mapper = $self->{_storage}->set_mapper( $value );
		return undef unless $mapper;
	    }
	    
	}
    } else {
	# At this point, the mapper is just the *name*, not the object.
	my $mapper_object;
	if ($mapper_name) {
	    $mapper_object = $self->{_storage}->set_mapper( $mapper_name );
	    Yggdrasil::fatal( "Unable to initialize the mapper '$mapper_name'" ) unless $mapper_object;
	} else {
	    $mapper_object = $self->{_storage}->get_default_mapper();
	    Yggdrasil::fatal( "Unable to initialize the default mapper" ) unless $mapper_object;
	}
	
	$self->{_storage}->define( $schema,
				  nomap  => 1,
				  fields => {
					     id    => { type => 'VARCHAR(255)' },
					     value => { type => 'TEXT' },				  
					    },
				  hints  => { id => { key => 1 } },	       
				);
	$self->{_storage}->store( $schema, key => "id",
				 fields => { id => 'mapstruct', value => $self->get( 'mapper' ) });
	$self->{_storage}->store( $schema, key => "id",
				 fields => { id => 'temporalstruct', value => $self->get( 'temporal' ) });
	
	
	my $mappername = ref $mapper_object;
	$mappername =~ s/.*::(.*)$/$1/;
	$self->{_storage}->store( $schema, key => "id",
				 fields => { id => 'mapper', value => $mappername });
    }    
}

sub _define_auth {
    my $self = shift;
    my $schema = shift;
    my $originalname = shift;
    my $auth = shift;
    my $nomap = shift;

    my $authschema = join("_", "Storage", "userauth", $originalname);
    $self->{_storage}->define( $authschema,
			      fields => {
					 # FIX: id must be the same type as $schema's id
					 id     => { type => 'INTEGER', null => 0 },
					 roleid => { type => 'INTEGER', null => 0 },
					 w      => { type => 'BOOLEAN' },
					 r      => { type => 'BOOLEAN' },
					 'm'    => { type => 'BOOLEAN' },
					},
			      nomap => $nomap,
			      hints => {
					id     => { foreign => $schema },
					roleid => { foreign => $self->get( 'authrole' ) },
				       } );
    

    for my $action ( keys %$auth ) {
	my $restrictions = $auth->{$action};
	next unless $restrictions;

	for( my $i=0; $i<@$restrictions; $i+=2 ) {
	    my $authschema_binding    = $restrictions->[$i];
	    my $authschema_constraint = $restrictions->[$i+1];

	    # Change Foo:Auth, :Auth etc. to the real auth table
	    my $real_schema = $authschema_binding;
	    if( $authschema_binding eq ":Auth" ) {
		$real_schema = $authschema;
	    } elsif( $authschema_binding =~ /:Auth$/ ) {
		$real_schema = $self->{_storage}->_get_auth_schema_name( $authschema_binding );
	    }

	    $restrictions->[$i] = $real_schema;

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
		if( $schemaref eq $originalname ) {
		    unless( $nomap ) {
			my $mapped_schema = join(".", $schema, $schemafield);
			$where->[$f+1] = \$mapped_schema;
		    }

		    next;
		}

		# This is just for consistency checking - it has no
		# effect other than occationally dying.
		my @matches = $self->{_storage}->_find_schema_by_name_or_alias( $schemaref, $restrictions );

		if( @matches > 1 ) {
		    die "'$schemaref' is mentioned more than once in the definition of $originalname\n";
		}
		
		if( @matches == 0 ) {
		    die "'$schemaref' is never mentioned in the definition of $originalname\n";
		}
	    }
	}

	my @mapped = $self->{_storage}->_map_fetch_schema_references( @$restrictions );
	$auth->{$action} = \@mapped;
    }

    my $bindings = Storable::nfreeze( $auth );
    $self->{_storage}->_store( $self->get( 'authschema' ), 
			      key => [ qw/usertable authtable/ ],
			      fields => {
					 usertable => $schema,
					 authtable => $authschema,
					 bindings  => $bindings,
					 committer => $self->{_storage}->{bootstrap}?'bootstrap':$self->{_storage}->{user}->id(),
			     } );
}


1;
