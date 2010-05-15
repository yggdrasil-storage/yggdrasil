package Yggdrasil::Remote::Entity;

use strict;
use warnings;

use base qw/Yggdrasil::Entity/;

sub define {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    my $dataref = $self->storage()->{protocol}->define_entity( $params{entity} );
    return Yggdrasil::Object::objectify( $self->yggdrasil(), __PACKAGE__, $dataref );    
}

sub get {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    my $dataref = $self->storage()->{protocol}->get_entity( $params{entity} );
    return Yggdrasil::Object::objectify( $self->yggdrasil(), __PACKAGE__, $dataref );    
}

sub property_exists {
    my $self = shift;

    return $self->get_property( @_ );
}

sub fetch {
    my $self = shift;
    my $instance = shift;

    return Yggdrasil::Remote::Instance->fetch( yggdrasil => $self->yggdrasil(),
					       entity    => $self->{id},
					       instance  => $instance );
}

sub expire {
    my $self = shift;

    return $self->storage()->{protocol}->expire_entity( $self->name() );
}

sub get_property {
    my $self = shift;
    my $prop = shift;

    return Yggdrasil::Remote::Property->get( yggdrasil => $self->yggdrasil(),
					     entity    => $self,
					     property  => $prop,
					     @_ );
}

sub get_all {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    return Yggdrasil::Object::objectify(
					$self->yggdrasil(),
					__PACKAGE__,
					$self->storage()->{protocol}->get_all_entities(),
				       );
}

sub instances {
    my $self = shift;

    return Yggdrasil::Object::objectify(
					$self->yggdrasil(),
					__PACKAGE__,
					$self->storage()->{protocol}->get_all_instances( $self->name() ),
				       );
}

sub properties {
    my $self = shift;
    
    return Yggdrasil::Object::objectify(
					$self->yggdrasil(),
					'Yggdrasil::Remote::Property',
					$self->storage()->{protocol}->get_all_properties( $self->name() ),
				       );
}

sub create {
    my $self = shift;
    my $id   = shift;
    
    return Yggdrasil::Object::objectify(
					$self->yggdrasil(),
					'Yggdrasil::Remote::Instance',
					$self->storage()->{protocol}->create_instance( $self->name(), $id ),
				       );
    
}

1;
