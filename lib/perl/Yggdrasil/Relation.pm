package Yggdrasil::Relation;

use strict;
use warnings;

use base qw(Yggdrasil::MetaRelation);

our $SCHEMA = <<SQL;
CREATE TABLE [name] (
  id    INT NOT NULL AUTO_INCREMENT,
  lval  INT NOT NULL,
  rval  INT NOT NULL,
  start DATETIME NOT NULL,
  stop  DATETIME NULL,

  PRIMARY KEY( id ),
  FOREIGN KEY( lval ) REFERENCES [entity1]( id ),
  FOREIGN KEY( rval ) REFERENCES [entity2]( id ),
  CHECK( start < stop )
);
SQL

sub _define {
  my $self    = shift;
  my $entity1 = shift;
  my $entity2 = shift;

  $entity1 =~ s/.*:://;
  $entity2 =~ s/.*:://;

  my $name = join("_R_", $entity1, $entity2);

  unless (__PACKAGE__->exists( $name )) {
      # --- Create Relation table
      $self->{storage}->dosql_update($SCHEMA, { name => $name, entity1 => $entity1, entity2 => $entity2 } );
      
      # --- Add to MetaRelation
      $self->_meta_add($name, $entity1, $entity2);
  }
  
}

sub add {
  my $self      = shift;
  my $instance1 = shift;
  my $instance2 = shift;

  my $id1 = $instance1->{id};
  my $id2 = $instance1->{id};

  $self->{storage}->dosql_update( qq<INSERT INTO [name](lval,rval,start) VALUES(?,?,NOW())>, $self, [$id1, $id2] );
}


1;
