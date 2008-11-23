package Yggdrasil::Entity;

use strict;
use warnings;

# We inherit _add_meta from MetaEntity and _add_inheritance from
# MetaInheritance.
use base qw(Yggdrasil::MetaEntity Yggdrasil::MetaInheritance);

sub _define {
    my $self  = shift;
    my $name  = shift;
    my %params = @_;

    my $package = join '::', $self->{namespace}, $name;

    # --- Add to MetaEntity, noop if it exists.
    $self->_meta_add($name);

    # --- Update MetaInheritance
    if( defined $params{inherit} ) {
	my $parent = Yggdrasil::_extract_entity($params{inherit});
	$self->_add_inheritance( $name, $parent );
    } else {
	$self->_expire_inheritance( $name );
    }

    # --- Create namespace, redefined if it exists.
    $self->_register_namespace( $package );
    
    return $package;
}

sub _get {
    my $self  = shift;
    my $name  = shift;

    # FIX: check if exists
    return join '::', $self->{namespace}, $name;
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
