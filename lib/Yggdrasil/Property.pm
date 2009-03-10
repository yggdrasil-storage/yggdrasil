package Yggdrasil::Property;

use strict;
use warnings;

use base qw(Yggdrasil::Meta);

use Yggdrasil::Status;

sub _define {
  my $self    = shift;
  my $entity   = shift; # object.
  my $property = shift; # string.
  my %data     = @_;
  
  my $yggdrasil = $self->{yggdrasil} = $data{yggdrasil};
  my $storage   = $yggdrasil->{storage};

  my $status = new Yggdrasil::Status;
  unless (length $property) {
      $status->set( 400, "Unable to create properties with zero length names." );
      return;
  }
  
  $entity = $entity->{name};

  my $name;

  # Input types:
  # $somepointer->define_property( Foo::Bar::Baz:prop )
  # $baz_entity->define_property( prop );
  
  # Auth passes MetaAuthUser request as a MetaAuth object, hackish.
  # This catches requests on the form MetaAuthRole:password and similar constructs.
  if ($property =~ /:/) {
      my $real_entity   = (split /::/, $property)[-1];
      ($entity, $property) = (split /:/, $real_entity);
      $name = $property;
  }
  
  $name = join(":", $entity, $property);
  
  # print "$name :: $entity :: $property\n";
  
  # --- Set the default data type.
  $data{type} = uc $data{type} || 'TEXT';
  $data{null} = 1 if $data{null} || ! defined $data{null};
  
  # --- Create Property table
  $storage->define( $name,
		    fields   => { id    => { type => "INTEGER" },
				  value => { type => $data{type},
					     null => $data{null}}},
		    
		    temporal => 1,
		    hints => { id => { index => 1, foreign => 'Entities' }},
		  );
  
  my $idref = $storage->fetch( MetaEntity => { return => 'id',
					       where  => [ entity => $entity ] } );


  unless (@$idref) {
      $status->set( 400, "Unknown entity '$entity' requested for property '$property'." );
      return;
  }
  
  # --- Add to MetaProperty
  $storage->store("MetaProperty", key => "id",
		  fields => { entity   => $idref->[0]->{id},
			      property => $property,
			      type     => $data{type},
			      nullp    => $data{null},
			    } ) unless $data{raw};

  if ($status->status() == 202) {
      $status->set( 202, "Property '$property' already existed for '$entity'." );
  } else {
      $status->set( 201, "Property '$property' created for '$entity'." );
  }
  
  return $property;
}

sub _admin_dump {
    my $self = shift;
    my $entity = shift;
    my $property = shift;

    my $schema = join(":", $entity, $property);
    return $self->{storage}->raw_fetch( $schema );
}

sub _admin_restore {
    my $self = shift;
    my $entity = shift;
    my $property = shift;
    my $data = shift;

    my $schema = join(":", $entity, $property);

    $self->{storage}->raw_store( $schema, fields => $data );
}

sub _admin_define {
    my $self = shift;
    my $entity = shift;
    my $property = shift;

    my $eid = $self->{storage}->fetch( MetaEntity => 
				       { return => "id",
					 where  => [ entity => $entity ] } );


    $eid = $eid->[0]->{id};
    my $type = $self->{storage}->fetch( "MetaProperty" => 
					{ return => "type",
					  where => [ entity   => $eid,
						     property => $property ] } );
    
    $type = $type->[0]->{type} || "TEXT";
    $self->_define( $entity, $property, type => $type, raw => 1 );
    
}

1;

