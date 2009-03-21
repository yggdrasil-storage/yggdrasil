package Yggdrasil::Property;

use strict;
use warnings;

use base qw(Yggdrasil::Meta);

use Yggdrasil::Utilities qw|ancestors get_times_from|;

sub _define {
  my $self    = shift;
  my $entity   = shift; # object.
  my $property = shift; # string.
  my %data     = @_;
  
  my $yggdrasil = $self->{yggdrasil} = $data{yggdrasil};
  my $storage   = $yggdrasil->{storage};

  my $status = $self->get_status();
  unless (length $property) {
      $status->set( 400, "Unable to create properties with zero length names." );
      return;
  }
  
  $entity = $self->{entity} = $entity->{name};

  my $name;

  # Input types:
  # $ygg->define_property( Foo::Bar::Baz:prop )
  # $baz_entity->define_property( prop );
  
  # Auth passes MetaAuthUser request as a MetaAuth object, hackish.
  # This catches requests on the form MetaAuthRole:password and similar constructs.
  if ($property =~ /:/) {
      my @parts = split /::/, $property;
      my $last = pop @parts;
      ($entity, $property) = (split /:/, $last, 2);
      push( @parts, $entity );
      $entity = join('::', @parts);
  }
  
  $name = join(":", $entity, $property);
  $self->{name} = $property;
  
  # --- Set the default data type.
  $data{type} = uc $data{type} || 'TEXT';
  $data{null} = 1 if $data{null} || ! defined $data{null};

  my $idref = $storage->fetch( MetaEntity => { return => 'id',
					       where  => [ entity => $entity ] } );

  unless (@$idref) {
      $status->set( 400, "Unknown entity '$entity' requested for property '$property'." );
      return;
  }

  # --- Create Property table
  $storage->define( $name,
		    fields   => { id    => { type => "INTEGER" },
				  value => { type => $data{type},
					     null => $data{null}}},
		    
		    temporal => 1,
		    hints => { id => { index => 1, foreign => 'Entities' }},
		  );
  
  
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
  
  return $self;
}

sub null {
    my ($self) = (shift, shift);
    return $self->_get_meta( 'null', @_ );
}

sub type {
    my ($self, $property) = (shift, shift);
    return $self->_get_meta( 'type', @_ );
}

# _get_meta returns meta data for a property, information about nullp
# and type is currently supported.
sub _get_meta {
    my ($self, $meta) = (shift, shift);
    my ($start, $stop) = get_times_from( @_ );
    my $property = $self->{name};

    my $status = $self->get_status();

    unless ($meta eq 'null' || $meta eq 'type') {
	$status->set( 406, "$meta is not a valid metadata request" );
	return undef;
    }

    # The internal name for the null field is "nullp".
    $meta = 'nullp' if $meta eq 'null';

    my $entity = $self->{entity};
    my $storage = $self->{yggdrasil}->{storage};
    my @ancestors = ancestors($storage, $entity, $start, $stop);

    foreach my $e ( $self, @ancestors ) {
	my $ret = $storage->fetch('MetaEntity', { where => [ entity => $e->{entity} ]},
				  'MetaProperty',{ return => $meta,
						    where  => [ entity   => \qq{MetaEntity.id},
								property => $property ]},
				   { start => $start, stop => $stop });
	next unless @$ret;
	return $ret->[0]->{$meta};
    }
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

