package Yggdrasil::MetaEntity;

use strict;
use warnings;

use base qw(Yggdrasil::Meta);

sub _define {
    my $self = shift;

    return $self->{storage}->define( "MetaEntity",
				     fields   => { entity => { type => "VARCHAR(255)", null => 0, index => 1 } },
				     temporal => 1,
				     nomap    => 1 );
}

sub _meta_add {
    my $self = shift;
    my $name = shift;

    $self->{storage}->store( "MetaEntity", key => "entity", fields => { entity => $name } );
}

sub _admin_dump {
    my $self = shift;

    return $self->{storage}->raw_fetch( "MetaEntity" );
}

sub _admin_restore {
    my $self = shift;
    my $data = shift;

    return $self->{storage}->raw_store( "MetaEntity", fields => $data );
}

1;
