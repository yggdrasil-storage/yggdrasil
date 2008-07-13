package Yggdrasil;

use strict;
use warnings;

use Yggdrasil::Storage;
use Yggdrasil::MetaEntity;
use Yggdrasil::MetaProperty;
use Yggdrasil::MetaRelation;

use Yggdrasil::Relation;
use Yggdrasil::Entity;


sub new {
  my $class = shift;
  my $self  = {};

  bless $self, $class;

  $self->_init(@_);

  return $self;
}

sub bootstrap {
  my $self = shift;

  # create db stuff
  my $meta_entity = Yggdrasil::MetaEntity->new();
  $meta_entity->bootstrap();
 
  my $meta_relation = Yggdrasil::MetaRelation->new();
  $meta_relation->bootstrap();

  my $meta_property = Yggdrasil::MetaProperty->new();
  $meta_property->bootstrap();
}

sub _init {
  my $self = shift;

  # --- Fetch storage handler
  $self->{storage} = Yggdrasil::Storage->new(@_);
}

sub add_entity {
  my $self = shift;

  return Yggdrasil::Entity->new(@_);
}

sub get_entity {
  my $self = shift;

  return Yggdrasil::Entity->get( @_ );
}

sub add_relation {
  my $self = shift;

  return Yggdrasil::Relation->new(@_);  
}

1;
