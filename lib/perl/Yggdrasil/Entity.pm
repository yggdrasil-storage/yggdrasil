package Yggdrasil::Entity;

use strict;
use warnings;

use Yggdrasil::Storage;

use Yggdrasil::MetaEntity;
use Yggdrasil::Property;
use Yggdrasil::Entity::Instance;

our $SCHEMA = <<SQL;
CREATE TABLE [name] (
  id        INT NOT NULL AUTO_INCREMENT,
  visual_id TEXT NOT NULL,

  PRIMARY KEY( id ),
  UNIQUE( visual_id(100) )
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
  my %data = @_;

  $self->{name} = $data{name};
  
  my $storage = Yggdrasil::Storage->new();
  # --- Create Entity table
  $storage->dosql_update($SCHEMA, %data);

  # --- Create MetaEntity entry
  my $me = Yggdrasil::MetaEntity->new();
  $me->add( %data );
}

sub define_property {
  my $self = shift;
  my %data = @_;

  my $storage = Yggdrasil::Storage->new();

  # --- Create a property table
  my $propertytable = Yggdrasil::Property->new( entity => $self->{name}, %data );

  # --- Update MetaProperty table
  Yggdrasil::MetaProperty->add( entity => $self->{name}, property => $data{name} );

}

# Dette må vi tenke hardt på
# kun en "new"
sub get {
  my $class = shift;
  my $self = {};
  my %data = @_;

  $self->{name} = $data{name};
  return bless $self, $class;
}

sub add {
  my $self = shift;
  my $visual_id   = shift;

  my $storage = Yggdrasil::Storage->new();

  my $id = $storage->dosql_update( qq<INSERT INTO [name](visual_id) VALUES(?)>, name => $self->{name}, [$visual_id] );
  my $instance = Yggdrasil::Entity::Instance->new( entity => $self, id => $id );

  return $instance;
}

1;


