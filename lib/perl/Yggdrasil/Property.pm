package Yggdrasil::Property;

use strict;
use warnings;

use Yggdrasil::DB;

sub new {
  my $class = shift;
  my $self  = {};

  bless $self, $class;

  $self->_init(@_);

  return $self; 
}

sub _init {
  my $self = shift;
  my %data = @_;

  $self->{name} = $data{name};
  $self->{type} = $data{type};
  
  my $dbh = Yggdrasil::DB->new();

  # --- Create Property table
  $dbh->dosql_update(<DATA>, %data);

}

1;


__DATA__
CREATE TABLE [entity]_[name] (
  id     INT NOT NULL,
  value  TEXT NULL,
  start  DATETIME NOT NULL,
  stop   DATETIME NULL,

  PRIMARY KEY( id ),
  FOREIGN KEY( id ) REFERENCES [entity]( id ),
  CHECK( start < stop )
);

