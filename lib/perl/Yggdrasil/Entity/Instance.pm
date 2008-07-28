package Yggdrasil::Entity::Instance;

use base 'Yggdrasil::MetaProperty';

use strict;
use warnings;

our $SCHEMA = <<SQL;
CREATE TABLE [name] (
  id     INT NOT NULL,
  value  TEXT NULL,
  start  DATETIME NOT NULL,
  stop   DATETIME NULL,

  PRIMARY KEY( id, value(50), start ),
  FOREIGN KEY( id ) REFERENCES [entity]( id ),
  CHECK( start < stop )
);
SQL

sub new {
  my $class = shift;

  my( $pkg ) = caller();
  my $self = $class->SUPER::new(@_);

  return $self if $pkg ne 'Yggdrasil::Entity::Instance' && $pkg =~ /^Yggdrasil::/;

  # --- do stuff
  my $visual_id = shift;

  my $entity = $self->_extract_entity();
  $self->{_id} = $self->{storage}->fetch( $entity, visual_id => $visual_id );

  unless ($self->{_id}) { 
    $self->{_id} = $self->{storage}->update( $entity, visual_id => $visual_id );
    $self->property( "_$entity" => $visual_id );
  }

  return $self;
}

sub get {
  my $self = shift;
  my $visual_id = shift;

  print "--------> HERE <----------\n";

  return $self->new( $visual_id );
}

sub _define {
  my $self     = shift;
  my $property = shift;

  my( $pkg ) = caller(0);
  if( $property =~ /^_/ && $pkg !~ /^Yggdrasil::/ ) {
    die "You bastard! private properties are not for you!\n";
  }
  my $entity = $self->_extract_entity();
  my $name = join("_", $entity, $property);

  # --- Create Property table
  $self->{storage}->dosql_update( $SCHEMA, { name => $name, entity => $entity } );

  # --- Add to MetaProperty
  $self->_meta_add($entity, $property);
}

sub property {
    my $self = shift;
    my ($key, $value) = @_;

    my $storage = $self->{storage};

    my $entity = $self->_extract_entity();
    my $name = join("_", $entity, $key );
      
    if ($value) {
      $storage->update( $name, id => $self->{_id}, value => $value );
    }

    return $storage->fetch( $name, id => $self->{_id} );
}

sub relate {
  my $self     = shift;
  my $instance = shift;

  my $e1 = $self->_extract_entity();
  my $e2 = $instance->_extract_entity();

  my $storage = $self->{storage};

  my $schema = $storage->fetch( "MetaRelation", entity1 => $e1, entity2 => $e2 );
  print "-----------> [$schema]\n";


  $storage->update( $schema, lval => $self->{_id}, rval => $instance->{_id} );
}

1;
