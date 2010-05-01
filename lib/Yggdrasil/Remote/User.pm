package Yggdrasil::Remote::User;

use strict;
use warnings;

use base qw/Yggdrasil::User/;

sub get {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    my $dataref = $self->storage()->{protocol}->get_user( $params{user} );
    return unless $dataref;
    return bless $dataref, __PACKAGE__;
}

1;
