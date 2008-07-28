package Yggdrasil::MetaProperty;

use strict;
use warnings;

use base qw(Yggdrasil::Meta);

our $SCHEMA = <<SQL;
CREATE TABLE MetaProperty (
  id            INT NOT NULL AUTO_INCREMENT,
  entity        VARCHAR(255) NOT NULL,
  property      VARCHAR(255) NOT NULL,
  start         DATETIME NOT NULL,
  stop          DATETIME NULL DEFAULT NULL,

  PRIMARY KEY( id ),
  CHECK( start < stop )
);
SQL

sub _define {
    my $self = shift;

    $self->{storage}->dosql_update($SCHEMA);
}

sub _meta_add {
  my $self   = shift;
  my $entity = shift;
  my $key    = shift;

  $self->{storage}->update( "MetaProperty", entity => $entity, property => $key );
}

1;
