package Yggdrasil::MetaInheritance;

use strict;
use warnings;

use base qw(Yggdrasil::Object);

sub define {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my $storage = $self->{yggdrasil}->{storage};
    
    $storage->define( "MetaInheritance",
		      fields   => { parent => { type => "INTEGER", null => 0 },
				    child  => { type => "INTEGER", null => 0 } },
		      temporal => 1,
		      nomap    => 1,
		      hints    => {
				   parent => { foreign => 'MetaEntity' },
				   child  => { foreign => 'MetaEntity' }
				  });
}

sub add {
    my $class = shift;
    my $self   = $class->SUPER::new(@_);
    my $me     = $self->{yggdrasil}->{storage}->get_entity_id( shift );
    my $parent = $self->{yggdrasil}->{storage}->get_entity_id( shift );

    $self->{yggdrasil}->{storage}->store('MetaInheritance',
			    key    => [ 'parent', 'child' ],
			    fields => {
				       parent => $parent,
				       child  => $me,
				      });

}

sub expire {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    my $entity = $params{entity};

    my $me   = $self->{yggdrasil}->{storage}->get_entity_id( $entity );

    $self->{yggdrasil}->{storage}->expire('MetaInheritance', child => $me);
}

sub _admin_dump {
    my $self = shift;

    return $self->{yggdrasil}->{storage}->raw_fetch( "MetaInheritance" );
}

sub _admin_restore {
    my $self = shift;
    my $data = shift;

    return $self->{yggdrasil}->{storage}->raw_store( "MetaInheritance", fields => $data );
}

1;
