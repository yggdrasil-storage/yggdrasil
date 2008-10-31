package Yggdrasil::MetaInheritance;

use strict;
use warnings;

use base qw(Yggdrasil::Meta);

sub _define {
    my $self = shift;

    return $self->{storage}->define( "MetaInheritance",
				     fields   => { parent => { type => "INTEGER", null => 0 },
						   child  => { type => "INTEGER", null => 0 } },
				     temporal => 1,
				     nomap    => 1,
				     hints    => {
						  parent => { foreign => 'MetaEntity' },
						  child  => { foreign => 'MetaEntity' }
						 });
}

sub _add_inheritance {
    my $self   = shift;
    my $me     = $self->{storage}->get_entity_id( shift );
    my $parent = $self->{storage}->get_entity_id( shift );

    $self->{storage}->store('MetaInheritance',
			    key    => [ 'parent', 'child' ],
			    fields => {
				       parent => $parent,
				       child  => $me,
				      });

}

sub _expire_inheritance {
    my $self = shift;
    my $me   = $self->{storage}->get_entity_id( shift );

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
