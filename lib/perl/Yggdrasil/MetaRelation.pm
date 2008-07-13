package Yggdrasil::MetaRelation;

use strict;
use warnings;

use Yggdrasil::Storage;

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
  my ($e1, $e2) = @_;

  my $name = join("_R_", $e1->{name}, $e2->{name} );

  my $storage = Yggdrasil::Storage->new();
  $storage->dosql_update( qq<INSERT INTO MetaRelation(relation,entity1,entity2,start) VALUES(?, ?, ?, NOW())>, [$name, $e1->{name}, $e2->{name} ] );
}

1;

