package Yggdrasil::Remote::Entity;

use strict;
use warnings;

use base qw/Yggdrasil::Entity/;

sub get {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    my $dataref = $self->storage()->{protocol}->get_entity( $params{entity} );
    return unless $dataref;
    $dataref->{yggdrasil} = $self->yggdrasil();
    return bless $dataref, __PACKAGE__;
}

sub fetch {
    my $self = shift;
    my $instance = shift;

    return Yggdrasil::Remote::Instance->fetch( yggdrasil => $self->yggdrasil(),
					       entity    => $self->{id},
					       instance  => $instance );
}

1;
