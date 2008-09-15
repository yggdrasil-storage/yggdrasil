package Yggdrasil::Property;

use strict;
use warnings;

use base qw(Yggdrasil::Meta);

sub _define {
  my $self    = shift;
  my $entity   = shift;
  my $property = shift;
  my %data     = @_;

  die "Unable to create properties with zero length names.  Aborting.\n" unless length $property;
  
  $entity = Yggdrasil::_extract_entity($entity);
  my $name = join("_", $entity, $property);

  # --- Set the default data type.
  $data{type} = uc $data{type} || 'TEXT';
  
  # --- Create Property table
  $self->{storage}->define( $name,
			    fields   => { id    => { type => "INTEGER" },
					  value => { type => $data{type}, null => 1 } },
			    temporal => 1 );
  
  # --- Add to MetaProperty
  $self->{storage}->store( "MetaProperty", key => "id", fields => { entity => $entity, property => $property, type => $data{type} } ) unless $data{raw};

  return $property;
}

sub _admin_dump {
    my $self = shift;
    my $entity = shift;
    my $property = shift;

    my $schema = join("_", $entity, $property);
    return $self->{storage}->raw_fetch( $schema );
}

sub _admin_restore {
    my $self = shift;
    my $entity = shift;
    my $property = shift;
    my $data = shift;

    my $schema = join("_", $entity, $property);

    $self->{storage}->raw_store( $schema, fields => $data );
}

sub _admin_define {
    my $self = shift;
    my $entity = shift;
    my $property = shift;

    my $type = $self->{storage}->fetch( "MetaProperty" => { return => "type",
							    where => { entity => $entity,
								       property => $property } } );
    
    $type = $type->[0]->{type} || "TEXT";
    $self->_define( $entity, $property, type => $type, raw => 1 );
    
}

1;

