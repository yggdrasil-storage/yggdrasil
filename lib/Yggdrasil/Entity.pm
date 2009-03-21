package Yggdrasil::Entity;

use strict;
use warnings;

use base qw(Yggdrasil::Object);

use Yggdrasil::Entity::Instance;

use Yggdrasil::MetaEntity;
use Yggdrasil::MetaInheritance;

use Yggdrasil::Property;

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

    my @entities = split /::/, $fqn;
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
	Yggdrasil::MetaInheritance->add( yggdrasil => $self, $fqn, $parent );
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
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    my $entity = $params{entity};
    
    my $aref = $self->storage()->fetch( 'MetaEntity', { where => [ entity => $entity ],
							return => 'entity' } );
    
    unless (defined $aref->[0]->{entity}) {
	my $status = new Yggdrasil::Status;
	$status->set( 404, "Entity '$entity' not found." );
	return undef;
    } 
    
    my $status = new Yggdrasil::Status;
    $status->set( 200 );
    my $obj = new Yggdrasil::Entity( name => $entity, yggdrasil => $self );
    $obj->{name} = $entity;
    return $obj;
}

sub undefine {

}

# instance
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
					     entity    => $self->{name},
					     yggdrasil => $self );    
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
					    entity    => $self->{name},
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
	$obj->{entity}    = $self->{name};
	$obj->{yggdrasil} = $self->{yggdrasil};
 	$obj->{storage}   = $self->{yggdrasil}->{storage};
	for my $key (keys %$hit) {
	    $obj->{$key} = $hit->{$key};
	}
	push @hits, $obj;
    }
    return @hits;
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
