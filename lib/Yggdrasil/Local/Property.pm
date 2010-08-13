package Yggdrasil::Local::Property;

use strict;
use warnings;

use base qw/Yggdrasil::Property/;

use Yggdrasil::Utilities qw|get_times_from|;

sub define {
    my $class  = shift;
    my $self   = $class->SUPER::new(@_);
    my %params = @_;

    # Deal with possibly being passed objects.  However, the property
    # is the id of the thing we wish to define, it better *not* be an
    # object.
    my $entity   = ref $params{entity}?$params{entity}->_userland_id():$params{entity};
    my $property = $params{property};
    
    my $yggdrasil = $self->yggdrasil();
    my $storage   = $yggdrasil->storage();

    my $status = $self->get_status();
    unless (length $property) {
	$status->set( 400, "Unable to create properties with zero length names." );
	return;
    }
    
    # Input types:
    # $ygg->define_property( Foo::Bar::Baz:prop )
    # $baz_entity->define_property( prop );
    
    # Auth passes MetaAuthUser request as a MetaAuth object, hackish.
    # This catches requests on the form MetaAuthRole:password and similar constructs.
    if ($entity) {
	if( $property =~ /:/ ) {
	    $status->set( 406, "Unable to create properties with names containing ':'." );
	    return;
	}
    } elsif( $property =~ /:/ ) {
	my @parts = split m/::/, $property;
	my $last = pop @parts;
	($entity, $property) = (split m/:/, $last, 2);
	push( @parts, $entity );
	$entity = join('::', @parts);
    } else {
	# we have no entity and the property name contains no ":"
	# This means we were called as $ygg->define_property( "foo" );
	# that makes no sense!
	$status->set( 406, "Unable to determine correct entity for the property requested " );
	return;
    }
    
    my $name = join(":", $entity, $property);

    $self->{name}   = $property;
    $self->{entity} = $entity;

    # --- Set the default data type.
    $params{type}   = uc $params{type} if $params{type};
    $params{type} ||= 'TEXT';
    $params{nullp}  = 1 if $params{nullp} || ! defined $params{nullp};

    unless ($storage->is_valid_type( $params{type} )) {
	my $ptype = $params{type};
	$status->set( 400, "Unknown property type '$ptype' requested for property '$property'." );
	return;
    }
    
    my $idref = $storage->fetch( MetaEntity => { return => 'id',
						 where  => [ entity => $entity ] } );
    
    unless (@$idref) {
	$status->set( 400, "Unknown entity '$entity' requested for property '$property'." );
	return;
    }

    # --- Create Property table
    $storage->define( $name,
		      fields   => { id    => { type => "INTEGER" },
				    value => { type => $params{type},
					       null => $params{nullp}}},
		      
		      temporal => 1,
		      hints => { id => { index => 1, foreign => 'Instances', key => 1 } },
		      authschema => 1,
		      auth => {			       
			       create => [
					  'Instances:Auth' => {
							       where => [
									 id => \q<id>,
									 'm' => 1,
									],
							      }
					 ],
			       fetch => [ 
					 ':Auth' => {
						     where => [
							       id => \qq<$name.id>,
							       r  => 1,
							      ],
						    },
					],
			       expire => [
					  ':Auth' => {
						      where => [
								id  => \qq<$name.id>,
								'm' => 1,
							       ],
						     },
					 ],
			       update => [ 
					  ':Auth' => { 
						      where => [
								id => \qq<$name.id>,
								w  => 1,
							       ],
						     },
					 ],
			      },
		    );
    
    # --- Add to MetaProperty
    # Why isn't this in Y::MetaProperty?
    if ($status->status() == 202) {
	$self->{entity} = Yggdrasil::Local::Entity->get( entity => $self->entity(), yggdrasil => $self->yggdrasil() );
	$status->set( 202, "Property '$property' already exists with the requested structure for entity '$entity'" )
	  
    } elsif ($status->status() >= 400 ) {
	$status->set( 202, "Property '$property' already exists for '$entity', unable to create with requested parameters" );
    } else {
	$storage->store("MetaProperty", key => [qw/entity property/],
			fields => { entity   => $idref->[0]->{id},
				    property => $property,
				    type     => $params{type},
				    nullp    => $params{nullp},
				  } ) unless $params{raw};
	$self->{entity} = Yggdrasil::Local::Entity->get( entity => $self->entity(), yggdrasil => $self->yggdrasil() );	
	$status->set( 201, "Property '$property' created for '$entity'." );
    }

    return $self;
}

sub objectify {
    my %params = @_;
    
    my $obj = new Yggdrasil::Local::Property( name      => $params{name},
					      entity    => $params{entity},
					      yggdrasil => $params{yggdrasil} );
    $obj->{name}   = $params{name};
    $obj->{entity} = $params{entity};
    $obj->{_id}    = $params{id};
    $obj->{_start} = $params{start};
    $obj->{_stop}  = $params{stop};
    return $obj;
}

sub get {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    my %params = @_;    
    
    my $status = $self->get_status();
    my ($entityobj, $entity, $propname);

    if ($params{entity}) {
	$propname = $params{property};
    } else {
	my @parts = split m/::/, $params{property};
	my $last = pop @parts;
	($entity, $propname) = (split m/:/, $last, 2);
	push( @parts, $entity );
	$params{entity} = join('::', @parts);
    }

    if (ref $params{entity}) {
	$entityobj = $params{entity}; 
    } else {
	$entityobj = $self->yggdrasil()->get_entity( $params{entity} );
    }

    # property_exists does not require the entity to actually exist
    # for the test to be valid, so there's no reason to ask storage to
    # create a proper entity object above, hence we use objectify and
    # then call propert_exists on that object directly.
    my $prop = $entityobj->property_exists( $propname );
    if ($prop) {
	$self->{name}   = $propname;
	$self->{entity} = $entityobj;
	$self->{_id}    = $prop->{id};
	$self->{_start} = $prop->{start};
	$self->{_stop}  = $prop->{stop};
	$status->set( 200 );
	return $self;
    } else {
	$status->set( 404 );
	return undef;
    }
}

sub expire {
    my $self = shift;
    my $storage = $self->storage();

    # You might not have permission to do this, can fails now either way.
#    for my $instance ($self->{entity}->instances()) {
#	$storage->expire( $self->{entity}->_userland_id() . ':' . $self->_userland_id(), id => $self->{_id} );
#    }
    
    $storage->expire( 'MetaProperty', id => $self->{_id} );
    return 1 if $self->get_status()->OK();
    return;
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
    # FIX: why cant null() send 'nullp' as param instead of 'null' and void this test?
    $meta = 'nullp' if $meta eq 'null';

    my $entity = $self->{entity};
    my $storage = $self->{yggdrasil}->{storage};
    my @ancestors = $entity->ancestors($start, $stop);

    foreach my $e ( @ancestors ) {
	my $ret = $storage->fetch('MetaEntity', { where => [ entity => $e ] },
				  'MetaProperty',{ return => $meta,
						   where  => [ entity   => \qq{MetaEntity.id},
							       property => $property ]},
				  { start => $start, stop => $stop });
	
	next unless @$ret;
	return $ret->[0]->{$meta};
    }
}

sub can_write {
    return 0;
}

sub can_expire {
    my $self = shift;
    
    return $self->storage()->can( expire => 'MetaProperty', { id => $self->{_id} } );
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

