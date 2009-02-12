package Yggdrasil::Entity;

use strict;
use warnings;

use Yggdrasil::Entity::Instance;

# We inherit _add_meta from MetaEntity and _add_inheritance from
# MetaInheritance.
use base qw(Yggdrasil::MetaEntity Yggdrasil::MetaInheritance);

sub _define {
    my $self  = shift;    
    my %params = @_;
    my $name = $self->{name};
    
    # --- Add to MetaEntity, noop if it exists.
    $self->_meta_add($name);

    # --- Update MetaInheritance
    if( defined $params{inherit} ) {
	my $parent = Yggdrasil::_extract_entity($params{inherit});
	$self->_add_inheritance( $name, $parent );
    } else {
	$self->_expire_inheritance( $name );
    }

    return $self;
}

sub create {
    my $self  = shift;
    my $name  = shift;

    my $obj = $self->_get_instance( $name );
    
    my $status = new Yggdrasil::Status;

    if ($obj) {
	$status->set( 202, "Instance '$name' already existed for entity '$self->{name}'." );
    } else {
	$status->set( 201, "Created instance '$name' in entity'$self->{name}'." );
    }
    
    return new Yggdrasil::Entity::Instance( visual_id => $name,
					    entity    => $self->{name},
					    yggdrasil => $self->{yggdrasil} );    
}

sub _fetch {
    my $self  = shift;
    my $name  = shift;

    my $obj = $self->_get_instance( $name );

    my $status = new Yggdrasil::Status;
    unless ($obj) {
	$status->set( 404, "Instance '$name' not found in entity '$self->{name}'." );
	return undef;
    }
    
    $status->set( 200 );
    return new Yggdrasil::Entity::Instance( visual_id => $name,
					    entity    => $self->{name},
					    yggdrasil => $self->{yggdrasil} );    
}

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
