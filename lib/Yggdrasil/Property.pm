package Yggdrasil::Property;

use strict;
use warnings;

use base qw(Yggdrasil::Object);

use Yggdrasil::Utilities qw|get_times_from|;

sub define {
    my $class  = shift;
    my $self   = $class->SUPER::new(@_);
    my %params = @_;

    my $entity   = $params{entity};
    my $property = $params{property};
  
    my $yggdrasil = $self->yggdrasil();
    my $storage   = $yggdrasil->{storage};

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
	$entity = $entity->{name};
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

    $self->{name} = $property;
    $self->{entity} = $entity;

    # --- Set the default data type.
    $params{type} = uc $params{type} || 'TEXT';
    $params{null} = 1 if $params{null} || ! defined $params{null};

    my %valid_properties = $yggdrasil->get_property_types();
    unless ($valid_properties{$params{type}}) {
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

    # FIXME, we can get here without a value TYPE, that'll brake stuff.
    
    # --- Create Property table
    $storage->define( $name,
		      fields   => { id    => { type => "INTEGER" },
				    value => { type => $params{type},
					       null => $params{null}}},
		      
		      temporal => 1,
		      hints => { id => { index => 1, foreign => 'Instances' }},

		      auth => {			       
			       create => undef,
			       fetch => { $name => { id => '__SELF__' },
					  ':Auth' => {
						      id   => \qq<$name.id>,
						      read => 1,
						     },
					},
			       expire => { $name => { id => '__SELF__' },
					   ':Auth' => {
						       id     => \qq<$name.id>,
						       modify => 1,
						      },
					 },
			       update => { $name => { id => '__SELF__' },
					   ':Auth' => { 
						       id    => \qq<$name.id>,
						       write => 1,
						      },
					 },
			      },
		      
		    );
  
    
    # --- Add to MetaProperty
    # Why isn't this in Y::MetaProperty?
    $storage->store("MetaProperty", key => "id",
		    fields => { entity   => $idref->[0]->{id},
				property => $property,
				type     => $params{type},
				nullp    => $params{null},
			      } ) unless $params{raw};

    if ($status->status() == 202) {
	$status->set( 202, "Property '$property' already existed for '$entity'." );
    } else {
	$status->set( 201, "Property '$property' created for '$entity'." );
    }
  
    return $self;
}

sub objectify {
    my %params = @_;
    
    my $obj = new Yggdrasil::Property( name      => $params{name},
				       entity    => $params{entity},
				       yggdrasil => $params{yggdrasil} );
    $obj->{name} = $params{name};
    $obj->{entity} = $params{entity};
    return $obj;
}

sub name {
    my $self = shift;

    return $self->{name};
}

sub entity {
    my $self = shift;

    return $self->{entity};
}


sub full_name {
    my $self = shift;

    # Testing is the only thing that uses this method, and it has
    # managed to make $self->{entity} a string...
    return join(':', $self->{entity}, $self->{name} );
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
	$entityobj = Yggdrasil::Entity::objectify( name      => $params{entity},
						   yggdrasil => $self );
    }

    # property_exists does not require the entity to actually exist
    # for the test to be valid, so there's no reason to ask storage to
    # create a proper entity object above, hence we use objectify and
    # then call propert_exists on that object directly.
    my $prop = $entityobj->property_exists( $propname );
    if ($prop) {
	$self->{name}   = $propname;
	$self->{entity} = $entityobj;
	$self->{_start} = $prop->{start};
	$self->{_stop}  = $prop->{stop};
	$status->set( 200 );
	return $self;
    } else {
	$status->set( 404 );
	return undef;
    }
}

sub undefine {

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
    # FIX: why cant null() send 'nullp' as param instead of 'null' and void this test?
    $meta = 'nullp' if $meta eq 'null';

    my $entity = $self->{entity};
    my $storage = $self->{yggdrasil}->{storage};
    my @ancestors = $entity->ancestors($start, $stop);

    foreach my $e ( $self, @ancestors ) {
	my $ret = $storage->fetch('MetaEntity', { where => [ entity => $e->{entity}->name() ]},
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

