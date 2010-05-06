package Yggdrasil::Remote::Entity;

use strict;
use warnings;

use base qw/Yggdrasil::Entity/;

sub get {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    my $dataref = $self->storage()->{protocol}->get_entity( $params{entity} );
    return Yggdrasil::Object::objectify( $self->yggdrasil(), __PACKAGE__, $dataref );    
}

sub fetch {
    my $self = shift;
    my $instance = shift;

    return Yggdrasil::Remote::Instance->fetch( yggdrasil => $self->yggdrasil(),
					       entity    => $self->{id},
					       instance  => $instance );
}

sub get_property {
    my $self = shift;
    my $prop = shift;

    return Yggdrasil::Remote::Property->get( yggdrasil => $self->yggdrasil(),
					     entity    => $self->{id},
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

1;
