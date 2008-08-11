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

  # --- Create Relation table
  $self->{storage}->define( $name,
			    fields   => {
					 id   => { type => 'SERIAL'  },
					 lval => { type => "INTEGER" },
					 rval => { type => "INTEGER" },
					},
			    temporal => 1 );
  
  # --- Add to MetaRelation
  $self->_meta_add($name, $entity1, $entity2);
}

1;
