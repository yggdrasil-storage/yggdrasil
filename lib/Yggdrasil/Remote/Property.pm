package Yggdrasil::Remote::Property;

use strict;
use warnings;

use base qw/Yggdrasil::Property/;

sub get {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    my $dataref = $self->storage()->{protocol}->get_property( $params{entity}->{id}, $params{property} );
    return unless $dataref;
    $dataref->{yggdrasil} = $self->yggdrasil();
    $dataref->{entity}    = $params{entity};
    return bless $dataref, __PACKAGE__;
}

sub define {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    my $dataref = $self->storage()->{protocol}->define_property( $params{entity}->{id},
								 $params{property},
								 $params{type},
								 $params{nullp} );
    return unless $dataref;
    $dataref->{yggdrasil} = $self->yggdrasil();
    return bless $dataref, __PACKAGE__;
}

sub expire {
    my $self = shift;
    return $self->storage()->{protocol}->expire_property( $self->entity()->_userland_id(), $self->_userland_id() );
}

sub _get_meta {
    my ($self, $type) = (shift, shift);
    return $self->storage()->{protocol}->get_property_meta( $self->entity()->_userland_id(), $self->_userland_id(), $type );
}

1;
