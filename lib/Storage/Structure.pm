package Storage::Structure;

use strict;
use warnings;

sub new {
    my $class  = shift;
    my %params = @_;
    
    my $self = {
		mapper        => 'mapname',
		temporal      => 'temporals',
		filter        => 'filter',
		config        => 'config',
		defines       => 'defines',
		ticker        => 'ticker',
		authschema    => 'authschema',
		authuser      => 'auth_user',
		authrole      => 'auth_role',
		authmember    => 'auth_membership',
		hasauthschema => 'hasauthschema',

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

sub bootstrap {
    my $self = shift;

    $self->_bootstrap_ticker();
    $self->_bootstrap_defines();
    $self->_bootstrap_config();
    $self->_bootstrap_filter();
    $self->_bootstrap_mapper();
    $self->_bootstrap_temporal();
    $self->_bootstrap_auth();
    $self->_bootstrap_fields();
}

sub init {
    my $self = shift;
    
    $self->_initialize_config();

    unless ($self->{_storage}->cache_is_populated()) {
	$self->_initialize_filter();
	$self->_initialize_mapper();
	$self->_initialize_temporal();
	$self->_initialize_hasauthschema();
    }

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

sub construct_userauth_from_schema {
    my $self = shift;
    my $schema = shift;

    return join("_", "Storage", "userauth", $schema);
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

sub _bootstrap_auth {
    my $self = shift;

    $self->_bootstrap_hasauthschema();
    $self->_bootstrap_schema_auth();
    $self->_bootstrap_user_auth();
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
    } 
}

sub _bootstrap_mapper {
    my $self = shift;

    $self->{_storage}->define( $self->get( 'mapper' ),
			       nomap  => 1,
			       fields => {
					  humanname  => { type => 'TEXT' },
					  mappedname => { type => 'TEXT' },
					 },
			     );
}

sub _bootstrap_defines {
    my $self = shift;

    $self->{_storage}->define( $self->get( 'defines' ),
			       nomap  => 1,
			       fields => {
					  schemaname => { type => 'TEXT' },
					  define     => { type => 'BINARY' },
					 },
			     );
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
    }
}

sub _bootstrap_temporal {
    my $self = shift;

    $self->{_storage}->define( $self->get( 'temporal' ),
			       nomap  => 1,
			       fields => {
					  tablename => { type => 'TEXT' },
					  temporal  => { type => 'BOOLEAN' },
					 },
			     );
}

sub _bootstrap_ticker {
    my $self = shift;
    
    $self->{_storage}->define( $self->get( 'ticker' ),
			       nomap  => 1,
			       fields => {
					  id        => { type => 'SERIAL' },
					  committer => { type => 'TEXT' },
					  event     => { type => 'TEXT' },
					  target    => { type => 'TEXT' },
					  stamp     => { type => 'TIMESTAMP', 
							 null => 0,
							 default => "current_timestamp" },
					 }, );
    $self->{_storage}->tick( 'define', $self->get( 'ticker' ));
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
    }
}

sub _bootstrap_filter {
    my $self = shift;

    $self->{_storage}->define( $self->get( 'filter' ),
			       nomap  => 1,
			       fields => {
					  id         => { type => 'SERIAL' },
					  schemaname => { type => 'TEXT', null => 0 },
					  filter     => { type => 'TEXT', null => 0 },
					  field      => { type => 'TEXT', null => 0 },
					  params     => { type => 'TEXT', null => 0 },
					 } );
}


sub _initialize_hasauthschema {
    my $self = shift;
    my $schema = $self->get( 'hasauthschema' );

    if ($self->{_storage}->_structure_exists( $schema )) {
	my $listref = $self->{_storage}->fetch( $schema, { return => '*' });
	for my $authpair (@$listref) {
	    my ($table, $auth) = ( $authpair->{tablename}, $authpair->{hasauth} );
	    $self->{_storage}->cache( 'hasauthschema', $table, $auth );
	}
    }
}

sub _bootstrap_hasauthschema {
    my $self = shift;

    $self->{_storage}->define( $self->get( 'hasauthschema' ),
			       nomap  => 1,
			       fields => {
					  tablename => { type => 'TEXT' },
					  hasauth   => { type => 'BOOLEAN' },
					 },
			     );
}



sub _bootstrap_user_auth {
    my $self = shift;
    my $userschema   = $self->get( 'authuser' );
    my $roleschema   = $self->get( 'authrole' );
    my $memberschema = $self->get( 'authmember' );
    
    $self->{_storage}->define( $roleschema,
			       nomap  => 1,
			       temporal => 1,
			       fields => {
					  id   => { type => 'SERIAL', null => 0 },
					  name => { type => 'TEXT', null => 0 },
					 },
			       hints    => { id => { index => 1 } },
			       authschema => 1,
			       auth => {
					create =>
					[
					 qq<$memberschema> => {
							       where => [ roleid => 1 ],
							      }
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

    $self->{_storage}->define( $userschema,
			       nomap  => 1,
			       temporal => 1,
			       fields => {
					  id       => { type => 'SERIAL', null => 0 },
					  name     => { type => 'TEXT', null => 0 },
					 },
			       authschema => 1,
			       hints    => { id => { index => 1 } },
			       auth => {
					create =>
					[
					 qq<$memberschema> => {
							       where => [ roleid => 1 ],
							      }
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

    $self->{_storage}->define( $memberschema,
			       nomap  => 1,
			       temporal => 1,
			       fields => {
					  userid => { type => 'INTEGER', null => 0 },
					  roleid => { type => 'INTEGER', null => 0 },
					 },
			       hints    => {
					    userid => { foreign => $userschema, index => 1 },
					    roleid => { foreign => $roleschema, index => 1 },
					   },
			       authschema => 0,
			       auth     => {
					    create => 
					    [
					     qq<$memberschema> => {
								   where => [ roleid => 1 ],
								  }
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

# FIXME, permissions.  
sub _bootstrap_fields {
    my $self = shift;
    my $structhash = $self->internal( 'userfields' );
    my $memberschema = $self->get( 'authmember' );

    for my $structure (keys %{$structhash}) {
	for my $fieldname (keys %{$structhash->{$structure}}) {
	    my $type = $structhash->{$structure}->{$fieldname};
	    my $schema = $self->get( "$structure:$fieldname" );
	    #	my $authrole = $self->get( 'authrole' );
	    my $filter = $self->internal( 'filter' )->{$structure}->{$fieldname};
	    my @filterfiller = ();
	    @filterfiller = ( filter => $filter ) if $filter;
	
	    my $null = 0;
	    if( $fieldname eq "password" ) {
		$null = 1;
	    }

	    $self->{_storage}->define( $schema,
				       temporal => 1,
				       nomap  => 1,
				       fields => {
						  id    => { type => 'INTEGER', null => 0 },
						  value => {
							    type => $type,
							    null => $null,
							    @filterfiller,
							   },
						 },
				       hints  => { id => { foreign => $self->get( 'authuser' ), index => 1 } },
				       authschema => 1,
				       auth => {
						create =>
						[
						 qq<$memberschema> => {
								       where => [ roleid => 1 ],
								      }
						],
						
						fetch => 
						[
						 ':Auth' => {
							     where => [ id => \qq<$schema.id>,
									r  => 1],
							    },
						],
						
						update => 
						[
						 ':Auth' => {
							     where => [ id => \qq<$schema.id>,
									w  => 1 ],
							    },
						],
						
						expire =>
						[
						 ':Auth' => {
							     where => [ id  => \qq<$schema.id>,
									'm' => 1 ],
							    }
						],
					       }
				     );
	}
    }
}

sub _bootstrap_schema_auth {
    my $self = shift;
    my $schema = $self->get( 'authschema' );
    
    $self->{_storage}->define( $self->get( 'authschema' ),
			       nomap  => 1,
			       fields => {
					  usertable => { type => 'TEXT',
							 null => 0 },
					  authtable => { type => 'TEXT',
							 null => 0 },
					  type      => { type => 'TEXT',
						         null => 0 },
					  bindings  => { type => 'BINARY',
							 null => 1 } } );
}

# Initialize the STORAGE config, this structure is required to be
# accessible with the specific configuration for this
# Storage instance and its workings.  TODO, fix mapper setup.
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
		warn( "Ignoring request to use $mapper_name as the mapper, the Storage requires $value\n" )
		  if $mapper_name && $mapper_name ne $value;
		my $mapper = $self->{_storage}->set_mapper( $value );
		return undef unless $mapper;
	    }
	    
	}
    }
}

sub _bootstrap_config {
    my $self = shift;

    my $schema = $self->get( 'config' );

    # At this point, the mapper is just the *name*, not the object.
    my $mapper_name = $self->{_storage}->get_mapper();
    my $mapper_object;
    if ($mapper_name) {
	$mapper_object = $self->{_storage}->set_mapper( $mapper_name );
	Yggdrasil::fatal( "Unable to initialize the mapper '$mapper_name'" ) 
	  unless $mapper_object;
    } else {
	$mapper_object = $self->{_storage}->get_default_mapper();
	Yggdrasil::fatal( "Unable to initialize the default mapper" ) 
	  unless $mapper_object;
    }
	
    $self->{_storage}->define( $self->get( 'config' ),
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

    $self->{_storage}->store( $schema, key => "id",
			      fields => { id => "storageversion", value => $self->{_storage}->version() });

    $self->{_storage}->store( $schema, key => "id",
			      fields => { id => "engineversion", value => $self->{_storage}->engine_version() });

    $self->{_storage}->store( $schema, key => "id",
			      fields => { id => "enginetype", value => $self->{_storage}->engine_type() });

    my $mappername = ref $mapper_object;
    $mappername =~ s/.*::(.*)$/$1/;
    $self->{_storage}->store( $schema, key => "id",
			      fields => { id => 'mapper', value => $mappername });
}

sub _define_auth {
    my $self = shift;
    my $schema = shift;
    my $originalname = shift;
    my $auth = shift;
    my $nomap = shift;
    my $create_auth_schema = shift;


    if( $create_auth_schema ) {
	my $authschema = $self->construct_userauth_from_schema( $originalname );

	$self->{_storage}->cache( 'hasauthschema', $originalname, 1 );
	$self->{_storage}->store( $self->get( 'hasauthschema' ), 
				  key => 'tablename',
				  fields => { tablename => $originalname,
					      hasauth   => 1 } );
	
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
				   temporal => 1,
				   hints => {
					     id     => { foreign => $schema },
					     roleid => { foreign => $self->get( 'authrole' ), index => 1 },
					     w      => { index => 1 },
					     r      => { index => 1 },
					     'm'    => { index => 1 },
					    } );
    }

    for my $action ( keys %$auth ) {
	$self->{_storage}->set_auth( $originalname, $action => $auth->{$action} );
    }



}

1;
