package Yggdrasil::MetaEntity;

use strict;
use warnings;

use Yggdrasil::Storage;

our $SCHEMA = <<SQL;
CREATE TABLE MetaEntity (
  entity   VARCHAR(255) NOT NULL,
  start    DATETIME NOT NULL,
  stop     DATETIME NULL DEFAULT NULL,

  PRIMARY KEY( entity ),
  CHECK( start < stop )
);
SQL

sub new {
  my $class = shift;
  my $self  = {};

  bless $self, $class;

  return $self;
}

sub bootstrap {
  my $self = shift;

  my $storage = Yggdrasil::Storage->new();
  $storage->dosql_update($SCHEMA);
}

sub add {
  my $self = shift;
  my %data = @_;

  my $storage = Yggdrasil::Storage->new();
  $storage->dosql_update( qq<INSERT INTO MetaEntity(entity,start) VALUES(?, NOW())>, [$data{name}] );
}

1;

