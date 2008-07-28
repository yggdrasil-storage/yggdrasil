package Yggdrasil::MetaEntity;

use strict;
use warnings;

use base qw(Yggdrasil::Meta);

our $SCHEMA = <<SQL;
CREATE TABLE MetaEntity (
  entity   VARCHAR(255) NOT NULL,
  start    DATETIME NOT NULL,
  stop     DATETIME NULL DEFAULT NULL,

  PRIMARY KEY( entity ),
  CHECK( start < stop )
);
SQL

sub _define {
    my $self = shift;

    $self->{storage}->dosql_update($SCHEMA);
}

sub _meta_add {
    my $self = shift;
    my $name = shift;

    $self->{storage}->update( "MetaEntity", entity => $name );
}

1;
