package Yggdrasil::MetaRelation;

use strict;
use warnings;

use base qw(Yggdrasil::Meta);

sub _define {
  my $self = shift;
  
  return $self->{storage}->define( schema   => "MetaRelation",
				   fields   => { relation   => { type => "VARCHAR(255)", null => 0 },
						 entity1    => { type => "VARCHAR(255)", null => 0 },
						 entity2    => { type => "VARCHAR(255)", null => 0 },
						 constraint => { type => "VARCHAR(255)", null => 0 },
					       },
				   temporal => 1,
				   nomap    => 1 );
}

sub _meta_add {
  my $self     = shift;
  my $relation = shift;
  my $entity1  = shift;
  my $entity2  = shift;

  $self->{storage}->update( "MetaRelation", relation => $relation, 
			    entity1 => $entity1, entity2 => $entity2 );
}

1;
