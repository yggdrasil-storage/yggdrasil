package Yggdrasil::Storage::Structure;

use strict;
use warnings;

sub new {
    my $class  = shift;
    my %params = @_;
    
    my $self = {
		storage    => $params{storage},
		mapper     => 'Storage_mapname',
		temporal   => 'Storage_temporals',
		config     => 'Storage_config',
		ticker     => 'Storage_ticker',
		authschema => 'Storage_authschema',
		authuser   => 'Storage_auth_user',
		authrole   => 'Storage_auth_role',
		authmember => 'Storage_auth_membership',
	       };

    
    bless $self, $class;

    return $self;
}

sub init {
    my $self = shift;
    
    $self->_initialize_config();
    $self->_initialize_mapper();
    $self->_initialize_ticker();
    $self->_initialize_temporal();
    $self->_initialize_auth();
}

sub get {
    my $self = shift;
    return $self->_getter_setter( @_ );
}

sub set {
    my $self = shift;
    return $self->_getter_setter( @_ );
}

sub _getter_setter {
    my $self = shift;
    my ($key, $value) = @_;

    my $structure = $self->{$key};
    Yggdrasil::fatal( "Unknown structure '$key' requested" ) unless $structure;

    $self->{$key} = $value if $value;
    return $self->{$key};
}

# Initalize the mapper cache and, if needed, the schema to store schema
# name mappings.
sub _initialize_mapper {
    my $self = shift;
    my $schema = $self->get( 'mapper' );
    
    if ($self->{storage}->_structure_exists( $schema )) {
	# Populate map cache from existing storagemapper.	
	my $listref = $self->{storage}->fetch( $schema, { return => '*' } );
	
	for my $mappair (@$listref) {
	    my ( $human, $mapped ) = ( $mappair->{humanname}, $mappair->{mappedname} );
	    $self->{storage}->cache( 'mapperh2m', $human, $mapped );
	    $self->{storage}->cache( 'mapperm2h', $mapped, $human );
	}
    } else {
	$self->{storage}->define( $schema,
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

    if ($self->{storage}->_structure_exists( $schema )) {
	my $listref = $self->{storage}->fetch( $schema, { return => '*' });
	for my $temporalpair (@$listref) {
	    my ($table, $temporal) = ( $temporalpair->{tablename}, $temporalpair->{temporal} );
	    $self->{storage}->cache( 'temporal', $table, $temporal );
	}
    } else {
	$self->{storage}->define( $schema, 
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
    
    unless ( $self->{storage}->_structure_exists( $schema ) ) {
	$self->{storage}->define( $schema,
				  nomap  => 1,
				  fields => {
					     id    => { type => 'SERIAL' },
					     stamp => { type => 'TIMESTAMP', 
							null => 0,
							default => "current_timestamp" },
					    }, );
    }
}


sub _initialize_auth {
    my $self = shift;

    $self->_initialize_schema_auth();
    $self->_initialize_user_auth();
}

sub _initialize_user_auth {
    my $self = shift;
    my $userschema   = $self->get( 'authuser' );
    my $roleschema   = $self->get( 'authrole' );
    my $memberschema = $self->get( 'authmember' );
    
    unless ( $self->{storage}->_structure_exists( $roleschema ) ) {
	$self->{storage}->define( $roleschema,
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

    unless ( $self->{storage}->_structure_exists( $userschema ) ) {
	$self->{storage}->define( $userschema,
				  nomap  => 1,
				  fields => {
					     id       => { type => 'SERIAL', null => 0 },
					     name     => { type => 'TEXT', null => 0 },
					     password => { type => 'PASSWORD' }
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

    unless ( $self->{storage}->_structure_exists($memberschema) ) {
	$self->{storage}->define( $memberschema,
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

sub _initialize_schema_auth {
    my $self = shift;
    my $schema = $self->get( 'authschema' );
    
    unless ( $self->{storage}->_structure_exists( $schema ) ) {
	$self->{storage}->define( $schema,
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
    my $mapper_name = $self->{storage}->get_mapper();
    if ($self->{storage}->_structure_exists( $schema )) {
	my $listref = $self->{storage}->fetch( $schema, { return => '*' });
	for my $temporalpair (@$listref) {
	    my ($key, $value) = ( $temporalpair->{id}, $temporalpair->{value} );
	    
	    $self->set( 'mapper', $value ) if lc $key eq 'mapstruct' && $value && $value =~ /^Storage_/;
	    $self->set( 'temporal', $value ) if lc $key eq 'temporalstruct' && $value && $value =~ /^Storage_/;

	    if (lc $key eq 'mapper') {
		$self->{logger}->warn( "Ignoring request to use $mapper_name as the mapper, the Storage requires $value" )
		  if $mapper_name && $mapper_name ne $value;
		my $mapper = $self->{storage}->set_mapper( $value );
		return undef unless $mapper;
	    }
	    
	}
    } else {
	# At this point, the mapper is just the *name*, not the object.
	my $mapper_object;
	if ($mapper_name) {
	    $mapper_object = $self->{storage}->set_mapper( $mapper_name );
	    Yggdrasil::fatal( "Unable to initialize the mapper '$mapper_name'" ) unless $mapper_object;
	} else {
	    $mapper_object = $self->{storage}->get_default_mapper();
	    Yggdrasil::fatal( "Unable to initialize the default mapper" ) unless $mapper_object;
	}
	
	$self->{storage}->define( $schema,
				  nomap  => 1,
				  fields => {
					     id    => { type => 'VARCHAR(255)' },
					     value => { type => 'TEXT' },				  
					    },
				  hints  => { id => { key => 1 } },	       
				);
	$self->{storage}->store( $schema, key => "id",
				 fields => { id => 'mapstruct', value => $self->get( 'mapper' ) });
	$self->{storage}->store( $schema, key => "id",
				 fields => { id => 'temporalstruct', value => $self->get( 'temporal' ) });
	
	
	my $mappername = ref $mapper_object;
	$mappername =~ s/.*::(.*)$/$1/;
	$self->{storage}->store( $schema, key => "id",
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
    $self->{storage}->define( $authschema,
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

	for( my $i=1; $i<@$restrictions; $i+=2 ) {
	    my $authschema_constraint = $restrictions->[$i];

	    # Add a new uniq alias.  FIXME for rand.
	    my $uniq_alias = join("_", "_auth", int(rand()*100_000) );
	    $authschema_constraint->{_auth_alias} = $uniq_alias;
	}	

	for( my $i=0; $i<@$restrictions; $i+=2 ) {
	    my $authschema_binding    = $restrictions->[$i];
	    my $authschema_constraint = $restrictions->[$i+1];

	    # Change Foo:Auth, :Auth etc. to the real auth table
	    my $real_schema = $authschema_binding;
	    if( $authschema_binding eq ":Auth" ) {
		$real_schema = $authschema;
	    } elsif( $authschema_binding =~ /:Auth$/ ) {
		$real_schema = $self->{storage}->_get_auth_schema_name( $authschema_binding );
	    }

	    $restrictions->[$i] = $real_schema;

	    # Change any \q<Schema.field> to the uniq alias, ie.
	    # \q<uniq_alias.field>
	    my $where = $authschema_constraint->{where};
	    next unless ref $where;

	    for( my $f=0; $f<@$where; $f+=2 ) {
		my $field = $where->[$f];
		my $value = $where->[$f+1];
		next unless ref $value eq "SCALAR";

		my( $schemaref, $schemafield ) = split m/\./, $$value;
		if( $schemaref eq $originalname && ! $nomap ) {
		    my $mapped_schema = join(".", $schema, $schemafield);
		    $where->[$f+1] = \$mapped_schema;
		}


		my @matches = $self->{storage}->_find_schema_by_name_or_alias( $schemaref, $restrictions );

		if( @matches > 1 ) {
		    die "'$schemaref' is mentioned more than once in the definition of $originalname\n";
		}
		
		if( @matches == 0 && $schemaref ne $originalname ) {
		    die "'$schemaref' is never mentioned in the definition of $originalname\n";
		}
		
		unless( $schemaref eq $originalname ) {
		    my $new_ref = join(".", $matches[0]->{_auth_alias}, $schemafield );
		    $where->[$f+1] = \$new_ref;
		}
	    }
	}

	# set alias = _auth_alias and remove _auth_alias
	for( my $i=1; $i<@$restrictions; $i+=2 ) {
	    my $constraint = $restrictions->[$i];
	    $constraint->{alias} = $constraint->{_auth_alias};
	    delete $constraint->{_auth_alias};
	}
	my @mapped = $self->{storage}->_map_fetch_schema_references( @$restrictions );
	$auth->{$action} = \@mapped;
    }

    my $bindings = Storable::nfreeze( $auth );
    $self->{storage}->_store( $self->get( 'authschema' ), 
			      key => [ qw/usertable authtable/ ],
			      fields => {
					 usertable => $schema,
					 authtable => $authschema,
					 bindings  => $bindings,
					 committer => $self->{storage}->{bootstrap}?'bootstrap':$self->{storage}->{user}->id(),
			     } );
}


1;
