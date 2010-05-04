package Yggdrasil::Remote::Property;

use strict;
use warnings;

use base qw/Yggdrasil::Property/;

sub get {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    my $dataref = $self->storage()->{protocol}->get_property( $params{entity}, $params{property} );
    return unless $dataref;
    $dataref->{yggdrasil} = $self->yggdrasil();
    return bless $dataref, __PACKAGE__;
}

sub define {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    my $dataref = $self->storage()->{protocol}->define_property( $params{entity}, $params{property} );
    return unless $dataref;
    $dataref->{yggdrasil} = $self->yggdrasil();
    return bless $dataref, __PACKAGE__;
}

sub entity {
    my $self = shift;

    my $dataref = $self->storage()->{protocol}->get_entity( $self->{entity} );
    return unless $dataref;
    $dataref->{yggdrasil} = $self->yggdrasil();
    return bless $dataref, 'Yggdrasil::Remote::Entity';
}

sub name {
    my $self = shift;
    return $self->{name};
}

sub null {
    my $self = shift;
    return $self->_get_meta( 'null', @_ );
}

sub type {
    my ($self, $property) = (shift, shift);
    return $self->_get_meta( 'type', @_ );
}

sub _get_meta {
    my ($self, $type) = (shift, shift);
    return $self->storage()->{protocol}->get_property_meta( $self->{entity}, $self->{name}, $type );
}

1;
