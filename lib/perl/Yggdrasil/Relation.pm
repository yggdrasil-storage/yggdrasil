package Yggdrasil::Relation;

use strict;
use warnings;

use Yggdrasil::Storage;

our $SCHEMA = <<SQL;
CREATE TABLE [entity1]_R_[entity2] (
  id    INT NOT NULL AUTO_INCREMENT,
  lval  INT NOT NULL,
  rval  INT NOT NULL,
  start DATETIME NOT NULL,
  stop  DATETIME NULL,

  PRIMARY KEY( id ),
  KEY( lval, rval ),
  FOREIGN KEY( lval ) REFERENCES [entity1]( id ),
  FOREIGN KEY( rval ) REFERENCES [entity2]( id ),
  CHECK( start < stop )
);
SQL

sub new {
  my $class = shift;
  my $self  = {};

  bless $self, $class;

  $self->_init(@_);

  return $self; 
}

sub _init {
  my $self = shift;
  my $entity1 = shift;
  my $entity2 = shift;
  

  my $storage = Yggdrasil::Storage->new();
  # --- Create Relation table
  $storage->dosql_update($SCHEMA, entity1 => $entity1->{name}, entity2 => $entity2->{name} );

  # --- Create MetaRelation entry
  my $me = Yggdrasil::MetaRelation->new();
  $me->add( $entity1, $entity2  );
}

sub add {
  my $self = shift;
  my $instance1 = shift;
  my $instance2 = shift;

  my $n1 = $instance1->{entity}->{name};
  my $n2 = $instance2->{entity}->{name};

  my $id1 = $instance1->{id};
  my $id2 = $instance1->{id};

  my $table = join("_R_", $n1, $n2 );

  my $storage = Yggdrasil::Storage->new();

  my $id = $storage->dosql_update( qq<INSERT INTO [name](lval,rval,start) VALUES(?,?,NOW())>, name => $table, [$id1, $id2] );
}


1;

