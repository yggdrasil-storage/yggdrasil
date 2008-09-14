package Yggdrasil::MetaRelation;

use strict;
use warnings;

use base qw(Yggdrasil::Meta);

sub _define {
  my $self = shift;
  
  return $self->{storage}->define( "MetaRelation",
				   fields   => { relation    => { type => "VARCHAR(255)", null => 0 },
						 entity1     => { type => "VARCHAR(255)", null => 0 },
						 entity2     => { type => "VARCHAR(255)", null => 0 },
						 requirement => { type => "VARCHAR(255)", null => 1 },
					       },
				   temporal => 1,
				   nomap    => 1 );
}

sub _meta_add {
  my $self     = shift;
  my $relation = shift;
  my $entity1  = shift;
  my $entity2  = shift;

  $self->{storage}->store( "MetaRelation",
			   key    => "relation",
			   fields => {
				      relation => $relation, 
				      entity1 => $entity1,
				      entity2 => $entity2 
				     });
}

sub _admin_dump {
    my $self = shift;

    return $self->{storage}->raw_fetch( "MetaRelation" );
}

sub _admin_restore {
    my $self = shift;
    my $data = shift;

    return $self->{storage}->raw_store( "MetaRelation", fields => $data );
}


1;
