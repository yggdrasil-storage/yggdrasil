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
  
  $self->{storage}->dosql_update($SCHEMA);
}

sub _meta_add {
  my $self    = shift;
  my $entity1 = shift;
  my $entity2 = shift;

  $self->{storage}->dosql_update( qq<INSERT INTO MetaRelation(relation,entity1,entity2,start) VALUES(?, ?, ?, NOW())>, 
				  [$self->{name}, $entity1->{name}, $entity2->{name} ] );
}

1;
