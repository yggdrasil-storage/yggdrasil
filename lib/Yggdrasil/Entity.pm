package Yggdrasil::Entity;

use strict;
use warnings;

use base qw(Yggdrasil::Object);

use Yggdrasil::Entity::Instance;

use Yggdrasil::MetaEntity;
use Yggdrasil::MetaInheritance;

use Yggdrasil::Property;

use Yggdrasil::Utilities qw|ancestors get_times_from|;
  
# We inherit _add_meta from MetaEntity and _add_inheritance from
# MetaInheritance.
#use base qw(Yggdrasil::MetaEntity Yggdrasil::MetaInheritance);

sub define {
    my $class = shift;
    my $self  = $class->SUPER::new( @_ );
    my %params = @_;

    my $name   = $params{entity};
    my $parent = $params{inherit};

    my $fqn = $parent ? join('::', $parent, $name) : $name;

    my @entities = split m/::/, $fqn;
    if (@entities > 1) {
	$name   = pop @entities;
	$parent = join('::', @entities);

	if ($self->{yggdrasil}->{strict}) { # How about $self->strict() 
                                            # (with strict() living in Y::Object)
	    if( ! Yggdrasil::Entity->get( yggdrasil => $self, entity => $parent)  ) {
	    #if (! $self->{yggdrasil}->get_entity( $parent )) {
		my $status = $self->get_status();
		$status->set( 400, "Unable to access parent entity $parent." );
		return;
	    }
	} else {
	    # print " ** Create $fqn\n";
	}
    }
    $self->{name} = $fqn;

    # --- Add to MetaEntity, noop if it exists.
    Yggdrasil::MetaEntity->add( yggdrasil => $self, entity => $fqn );
    #$self->_meta_add($fqn);

    my $status = $self->get_status();
    return $self if $status->status() == 202;

    # --- Update MetaInheritance  
    if( defined $parent ) {
	Yggdrasil::MetaInheritance->add( yggdrasil => $self, child => $fqn, parent => $parent );
	#$self->_add_inheritance( $fqn, $parent );
    } else {
	# warnings, this does update, which sets status.
	#$self->_expire_inheritance( $fqn );
	Yggdrasil::MetaInheritance->expire( yggdrasil => $self, entity => $fqn );
    }

    return $self;
}

# get an entity
sub get {
    my $class = shift;

    my ($self, $status);
    # If you called this as $entity->get() you wanted fetch().
    if (ref $class) {
	$status = $class->get_status();
	$status->set( 406, "Calling get() as an object method, you probably wanted fetch() to get an instance" );
	return undef;
    } else {
	$self   = $class->SUPER::new(@_);
	$status = $self->get_status();	
    }
    
    my %params = @_;

    my $entity = $params{entity};
    
    my $aref = $self->storage()->fetch( 'MetaEntity', { where => [ entity => $entity ],
							return => 'entity' } );
    
    unless (defined $aref->[0]->{entity}) {
	$status->set( 404, "Entity '$entity' not found." );
	return undef;
    } 
    
    $status->set( 200 );
    return objectify( name => $entity, yggdrasil => $self->{yggdrasil} );
}

sub objectify {
    my %params = @_;
    
    my $obj = new Yggdrasil::Entity( name => $params{name}, yggdrasil => $params{yggdrasil} );
    $obj->{name} = $params{name};
    return $obj;
}

sub undefine {

}

# instance, FIX so that one tests the result from YEI before setting 201.
sub create {
    my $self  = shift;
    my $name  = shift;

    my $obj = $self->_get_instance( $name );
    
    my $status = $self->get_status();

    if ($obj) {
	$status->set( 202, "Instance '$name' already existed for entity '$self->{name}'." );
    } else {
	$status->set( 201, "Created instance '$name' in entity '$self->{name}'." );
    }
    
    return Yggdrasil::Entity::Instance->new( visual_id => $name,
					     entity    => $self,
					     yggdrasil => $self->{yggdrasil} ); 
}

sub fetch {
    my $self  = shift;
    my $name  = shift;

    my $obj = $self->_get_instance( $name );

    my $status = $self->get_status();
    unless ($obj) {
	$status->set( 404, "Instance '$name' not found in entity '$self->{name}'." );
	return undef;
    }
    
    $status->set( 200 );
    return new Yggdrasil::Entity::Instance( visual_id => $name,
					    entity    => $self,
					    yggdrasil => $self->{yggdrasil} );    
}

sub delete :method {
    # delete an instance
}


# should this be Y::E::I->get(...)?
sub _get_instance {
    my $self = shift;
    my $visual_id = shift;
    
    my $st   = $self->{yggdrasil}->{storage};
    my $aref = $st->fetch('MetaEntity', { 
					 where => [ entity => $self->{name}, 
						    id     => \qq{Entities.entity}, ],
					},
			  'Entities', {
				       return => "id",
				       where => [ 
						 visual_id => $visual_id,
						] } );
    return $aref->[0]->{id};
}

sub search {
    my ($self, $key, $value) = (shift, shift, shift);
    
    # Passing the possible time elements onwards as @_ to the Storage layer.
    my ($nodes) = $self->{storage}->search( $self->{entity}, $key, $value, @_);
    
    my @hits;
    for my $hit (@$nodes) {
	my $obj = bless {}, 'Yggdrasil::Entity::Instance';
	$obj->{entity}    = $self;
	$obj->{yggdrasil} = $self->{yggdrasil};
	for my $key (keys %$hit) {
	    $obj->{$key} = $hit->{$key};
	}
	push @hits, $obj;
    }
    return @hits;
}

sub name {
    my $self = shift;

    return $self->{name};
}

# Handle property definition and deletion
sub define_property {
    my $self = shift;
    my $name = shift;

    return Yggdrasil::Property->define( yggdrasil => $self, entity => $self, property => $name, @_ );
}

sub undefine_property {

}

sub get_property {
    my $self = shift;
    my $prop = shift;
    return Yggdrasil::Property->get( yggdrasil => $self, entity => $self, property => $prop, @_ );
}

# Handle property queries.
sub property_exists {
    my ($self, $property) = (shift, shift);
    my ($start, $stop) = get_times_from( @_ );
    
    my $storage = $self->{yggdrasil}->{storage};
    my @ancestors = ancestors($storage, $self->name(), $start, $stop);
    
    # Check to see if the property exists.
    foreach my $e ( $self->name(), @ancestors ) {
	my $aref = $storage->fetch('MetaEntity', { where => [ id     => \qq{MetaProperty.entity},
							      entity => $e,
							    ]},
				   'MetaProperty', { return => 'property',
						     where => [ property => $property ] },
				   { start => $start, stop => $stop });

	# The property name might be "0".
	return join(":", $e, $property) if defined $aref->[0]->{property};
    }
    
    return;
}

sub properties {
    my $self = shift;
    my ($start, $stop) = get_times_from( @_ );

    my $storage = $self->{yggdrasil}->{storage};
    my @ancestors = ancestors($storage, $self->name(), $start, $stop);

    my %properties;
    
    foreach my $e ( $self->name(), @ancestors ) {
	my $aref = $storage->fetch('MetaEntity', { where => [ id     => \qq{MetaProperty.entity},
							      entity => $e,
							    ]},
				   'MetaProperty', 
				    { return => 'property' },
				    { start  => $start, stop => $stop });


	for my $p (@$aref) {
	    my $eobj;

	    if ($e eq $self->name()) {
		$eobj = $self;
	    } else {
		$eobj = Yggdrasil::Entity::objectify( name => $e, yggdrasil => $self->{yggdrasil} );
	    }
	    
	    $properties{ $p->{property} } = Yggdrasil::Property::objectify( name      => $p->{property},
									    yggdrasil => $self->{yggdrasil},
									    entity    => $eobj );
	}
    }

    return values %properties;
}



sub _admin_dump {
    my $self   = shift;
    my $entity = shift;

    return $self->{storage}->raw_fetch( Entities => { where => [ entity => $entity ] } );
}

sub _admin_restore {
    my $self   = shift;
    my $data   = shift;

    $self->{storage}->raw_store( "Entities", fields => $data );

    my $id = $self->{storage}->raw_fetch( Entities =>
					  { return => "id", 
					    where => [ %$data ] } );
    return $id->[0]->{id};
}


1;
