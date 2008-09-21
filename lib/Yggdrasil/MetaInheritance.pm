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

sub _add_inheritance {
    my $self   = shift;
    my $me     = shift;
    my $parent = shift;

    $self->{storage}->store('MetaInheritance',
			    key    => 'id',
			    fields => {
				       parent => $parent,
				       child  => $me,
				      });

}

sub _expire_inheritance {
    my $self = shift;
    my $me   = shift;

    $self->{storage}->expire('MetaInheritance', child => $me);
}

sub _admin_dump {
    my $self = shift;

    return $self->{storage}->raw_fetch( "MetaInheritance" );
}

sub _admin_restore {
    my $self = shift;
    my $data = shift;

    return $self->{storage}->raw_store( "MetaInheritance", fields => $data );
}

1;
