package Yggdrasil::MetaInheritance;

use strict;
use warnings;

use base qw(Yggdrasil::Meta);

sub _define {
    my $self = shift;

    return $self->{storage}->define( schema   => "MetaInheritance",
				     fields   => { parent => { type => "VARCHAR(255)", null => 0 },
						   child  => { type => "VARCHAR(255)", null => 0 },
						   id     => { type => "SERIAL" } }
				     temporal => 1,
				     nomap    => 1 );
}

sub _meta_add {
    my $self   = shift;
    my $child  = shift;
    my $parent = shift;

    $self->{storage}->dosql_update( qq<INSERT INTO MetaInheritance(parent,child,start) VALUES(?, ?, NOW())>, [$parent->{name}, $child->{name}] );
}

1;
