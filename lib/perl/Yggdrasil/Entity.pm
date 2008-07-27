package Yggdrasil::Entity;

use strict;
use warnings;

use base qw(Yggdrasil::MetaEntity);

use Yggdrasil::Entity::Instance;

our $SCHEMA = <<SQL;
CREATE TABLE [name] (
  id        INT NOT NULL AUTO_INCREMENT,
  visual_id TEXT NOT NULL,

  PRIMARY KEY( id ),
  UNIQUE( visual_id(100) )
);
SQL


sub _define {
    my $self = shift;
    my $name = shift;

    # --- Tell Storage to create SCHEMA
    $self->{storage}->dosql_update( $SCHEMA, $self );

    # --- Add to MetaEntity;
    $self->_meta_add($name);

    my $package = join '::', $self->{namespace}, $name;
    eval "package $package; use base qw(Yggdrasil::Entity::Instance);";
    
}

sub _get {
    my $self = shift;
    my $name = shift;

    # FIX: Check that Entity actually exists?
    $self->{name} = $name;
}

sub add {
  my $self      = shift;
  my $visual_id = shift;

  # --- Insert visual-id info into entity
  my $id = $self->{storage}->dosql_update( 
      qq<INSERT INTO [name](visual_id) VALUES(?)>, $self, [$visual_id] );

  # --- Return Instance object representing the added info.
  return Yggdrasil::Entity::Instance->new( entity => $self, id => $id );
}

sub fetch {
    my $self      = shift;
    my $visual_id = shift;

    my $props = $self->{storage}->dosql_select(
	qq<SELECT * FROM MetaProperty WHERE entity = ?>, [$self->{name}]);

    my @props = map { $_->{property} } @$props;
    
}

sub derive {
    my $self   = shift;
    my %derive = @_;
    
    my $inherit = Yggdrasil::MetaInheritance->new();
    $inherit->_meta_add( $self, $derive{from} );
}

1;
