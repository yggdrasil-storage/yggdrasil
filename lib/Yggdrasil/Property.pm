package Yggdrasil::Property;

use strict;
use warnings;

use base qw(Yggdrasil::Meta);

sub _define {
  my $self    = shift;
  my $entity   = shift;
  my $property = shift;
  my %data     = @_;

  $entity = Yggdrasil::_extract_entity($entity);
  my $name = join("_", $entity, $property);

  # --- Set the default data type.
  $data{type} = uc $data{type} || 'TEXT';
  
  # --- Create Property table
  $self->{storage}->define( $name,
			    fields   => { id    => { type => "INTEGER" },
					  value => { type => $data{type} } },
			    temporal => 1 );
  
  # --- Add to MetaProperty
  $self->{storage}->store( "MetaProperty", key => "id", fields => { entity => $entity, property => $property, type => $data{type} } );

  return $property;
}

1;

