package Yggdrasil::MetaProperty;

use strict;
use warnings;

use base qw(Yggdrasil::Meta);

sub _define {
    my $self = shift;

    return $self->{storage}->define( "MetaProperty",
				     fields   => { entity   => { type => "VARCHAR(255)", null => 0 },
						   property => { type => "VARCHAR(255)", null => 0 },
						   type     => { type => "VARCHAR(255)", null => 0 },
						   id       => { type => "SERIAL" } },
				     temporal => 1,
				     nomap    => 1 );
}

sub _admin_dump {
    my $self = shift;

    return $self->{storage}->raw_fetch( "MetaProperty" );
}

sub _admin_restore {
    my $self = shift;
    my $data = shift;

    return $self->{storage}->raw_store( "MetaProperty", fields => $data );
}

1;
