package Yggdrasil::Relation;

use strict;
use warnings;

use base qw(Yggdrasil::MetaRelation);

sub _define {
  my $self    = shift;
  my $entity1 = shift;
  my $entity2 = shift;
  my %param   = @_;

  $entity1 = Yggdrasil::_extract_entity($entity1);
  $entity2 = Yggdrasil::_extract_entity($entity2);

  unless( $param{raw} ) {
      my $schema = $self->{storage}->_get_relation( $entity1, $entity2 );
      return $schema if $schema;
  }
  
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
  $self->_meta_add($name, $entity1, $entity2) unless $param{raw};
}

sub _admin_dump {
    my $self = shift;
    my $relation = shift;

    return $self->{storage}->raw_fetch( $relation );
}

sub _admin_restore {
    my $self = shift;
    my $entity1 = shift;
    my $entity2 = shift;
    my $data = shift;

    my $schema = join("_R_", $entity1, $entity2);

    $self->{storage}->raw_store( $schema, fields => $data );
}

sub _admin_define {
    my $self = shift;
    my $entity1 = shift;
    my $entity2 = shift;

    $self->_define( $entity1, $entity2, raw => 1 );
}

1;
