package Yggdrasil::MetaInheritance;

use strict;
use warnings;

use base qw(Yggdrasil::Meta);

our $SCHEMA = <<SQL;
CREATE TABLE MetaInheritance (
  id     INT NOT NULL AUTO_INCREMENT,
  parent VARCHAR(255) NOT NULL,
  child  VARCHAR(255) NOT NULL,
  start  DATETIME NOT NULL,
  stop   DATETIME NULL DEFAULT NULL,

  PRIMARY KEY( id ),
  CHECK( start < stop )
);
SQL

sub _define {
    my $self = shift;

    unless ($self->{storage}->get_meta('MetaInheritance')) {
	$self->{storage}->dosql_update($SCHEMA);
    }
}

sub _meta_add {
    my $self   = shift;
    my $child  = shift;
    my $parent = shift;

    $self->{storage}->dosql_update( qq<INSERT INTO MetaInheritance(parent,child,start) VALUES(?, ?, NOW())>, [$parent->{name}, $child->{name}] );
}

1;
