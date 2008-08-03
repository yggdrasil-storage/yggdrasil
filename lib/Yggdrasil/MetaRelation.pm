package Yggdrasil::MetaRelation;

use strict;
use warnings;

use base qw(Yggdrasil::Meta);

our $SCHEMA = <<SQL;
CREATE TABLE MetaRelation (
  relation VARCHAR(255) NOT NULL,
  entity1  VARCHAR(255) NOT NULL,
  entity2  VARCHAR(255) NOT NULL,
  requirement VARCHAR(255) NULL,
  start     DATETIME NOT NULL,
  stop      DATETIME NULL,

  PRIMARY KEY( relation ),
  CHECK( start < stop )
);
SQL

sub _define {
  my $self = shift;
  
  unless ($self->{storage}->get_meta('MetaRelation')) {
      $self->{storage}->dosql_update($SCHEMA);
  }
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
