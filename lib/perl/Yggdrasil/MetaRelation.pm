package Yggdrasil::MetaRelation;

use strict;
use warnings;

use Yggdrasil::DB;

sub new {
  my $class = shift;
  my $self  = {};

  bless $self, $class;


  return $self;
}

sub bootstrap {
  my $self = shift;
  
  my $dbh = Yggdrasil::DB->new();
  $dbh->dosql_update(<DATA>);
}

1;

__DATA__
CREATE TABLE MetaRelation (
  relation VARCHAR(255) NOT NULL,
  entity1  INT NOT NULL,
  entity2  INT NOT NULL,
  requirement VARCHAR(255) NULL,
  start     DATETIME NOT NULL,
  stop      DATETIME NULL,

  PRIMARY KEY( relation ),
  CHECK( start < stop )
);
