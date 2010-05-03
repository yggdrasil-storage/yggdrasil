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

1;
