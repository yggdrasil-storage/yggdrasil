package Yggdrasil::Property;

use strict;
use warnings;

use base qw(Yggdrasil::MetaProperty);

our $SCHEMA = <<SQL;
CREATE TABLE [name] (
  id     INT NOT NULL,
  value  TEXT NULL,
  start  DATETIME NOT NULL,
  stop   DATETIME NULL,

  PRIMARY KEY( id ),
  FOREIGN KEY( id ) REFERENCES [entity_name]( id ),
  CHECK( start < stop )
);
SQL

sub _define {
  my $self   = shift;
  my $entity = shift;
  my $key    = shift;

  $self->{entity} = $entity;
  $self->{key}    = $key;
  $self->{entity_name} = $entity->{name};
  $self->{name}   = join("_", $entity->{name}, $key);

  unless (__PACKAGE__->exists()) {
      # --- Create Property table
      $self->{storage}->dosql_update( $SCHEMA, $self );
      
      # --- Add to MetaProperty
      $self->_meta_add($entity, $key);
  }
}

sub add {
    my $self   = shift;
    my $entity = shift;
    my $value  = shift;

    $self->{storage}->dosql_update( qq<INSERT INTO [name] (id, value, start) VALUES(?, ?, NOW())>, $self, [$entity->{id}, $value] );
}

1;

