package Yggdrasil::MetaInheritance;

use strict;
use warnings;

use base qw(Yggdrasil::Meta);

sub _define {
    my $self = shift;

    return $self->{storage}->define( "MetaInheritance",
				     fields   => { parent => { type => "VARCHAR(255)", null => 0 },
						   child  => { type => "VARCHAR(255)", null => 0 },
						   id     => { type => "SERIAL" } },
				     temporal => 1,
				     nomap    => 1 );
}

sub _meta_add {
    my $self   = shift;
    my $child  = shift;
    my $parent = shift;

    $self->{storage}->store('MetaInheritance',
			    key    => 'id',
			    fields => {
				       parent => $parent->{name},
				       child  => $child->{name},
				      });

}

1;
