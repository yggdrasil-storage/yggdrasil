package Yggdrasil::MetaEntity;

use strict;
use warnings;

use base qw(Yggdrasil::Meta);

sub _define {
    my $self = shift;

    return $self->{storage}->define( schema   => "MetaEntity",
				     fields   => { entity => { type => "VARCHAR(255)", null => 0 } },
				     temporal => 1,
				     nomap    => 1 );
}

sub _meta_add {
    my $self = shift;
    my $name = shift;

    $self->{storage}->update( "MetaEntity", entity => $name );
}

1;
