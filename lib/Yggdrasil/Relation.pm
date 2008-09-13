package Yggdrasil::Relation;

use strict;
use warnings;

use base qw(Yggdrasil::MetaRelation);

sub _define {
  my $self    = shift;
  my $entity1 = shift;
  my $entity2 = shift;

  $entity1 =~ s/.*:://;
  $entity2 =~ s/.*:://;

  my $schema = $self->{storage}->_get_relation( $entity1, $entity2 );
  return $schema if $schema;
  
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
