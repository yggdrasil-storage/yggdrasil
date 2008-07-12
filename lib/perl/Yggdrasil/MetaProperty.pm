package Yggdrasil::MetaProperty;

use strict;
use warnings;

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

sub new {
  my $class = shift;
  my $self  = {};

  bless $self, $class;

  return $self;  
}

sub bootstrap {
  my $self = shift;

  my $dbh = Yggdrasil::DB->new();
  $dbh->dosql_update($SCHEMA);
}

sub add {
  my $self = shift;
  my %data = @_;

  my $dbh = Yggdrasil::DB->new();
  $dbh->dosql_update( qq<INSERT INTO MetaProperty(entity,property,start) VALUES(?, ?, NOW())>, [$data{entity}, $data{property}] );
}

1;

