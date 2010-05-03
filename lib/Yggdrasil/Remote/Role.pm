package Yggdrasil::Remote::Role;

use strict;
use warnings;

sub name {
    my $self = shift;
    return $self->{name};
}

1;
