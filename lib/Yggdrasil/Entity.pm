package Yggdrasil::Entity;

use strict;
use warnings;

use base qw(Yggdrasil::Object);

use Yggdrasil::Instance;
use Yggdrasil::MetaEntity;
use Yggdrasil::Property;

use Yggdrasil::Utilities qw|get_times_from|;

our $UNIVERSAL = "UNIVERSAL";

sub define {
    my $class  = shift;
    my $self   = $class->SUPER::new( @_ );
    my %params = @_;

    my $name   = $params{entity};
    my $parent = $params{inherit};

    my $fqn = $parent ? join('::', $parent, $name) : $name;

    my @entities = split m/::/, $fqn;

    # Name is always the last part of Parent1::Parent2::Child
    $name   = pop @entities;

    # Parent name is Parent1::Parent2
    $parent = @entities ? join('::', @entities) : undef;
    
    # In cases where we have no parent and we're not talking about
    # UNIVERSAL, then our parent should be UNIVERSAL, eg. if name ==
    # "Student" etc. UNIVERSAL should not be parent of UNIVERSAL
    $parent = $UNIVERSAL if ! defined $parent && $name ne $UNIVERSAL;

    my $parent_id = undef;
    my $status = $self->get_status();
    if( defined $parent ) {
	my $pentity = Yggdrasil::Entity->get( yggdrasil => $self,
					      entity    => $parent );

	unless( $pentity ) {
	    $status->set( 400, "Unable to access parent entity $parent." );
	    return;
	}

	$parent_id = $pentity->{_id};
    }

    # --- Add to MetaEntity, noop if it exists.
    my %entity_params = (
			 yggdrasil => $self,
			 entity    => $fqn,
			);

    if( defined $parent_id ) {
	$entity_params{parent} = $parent_id;
    }

    Yggdrasil::MetaEntity->add( %entity_params );
    return unless $status->OK();

    return __PACKAGE__->get( yggdrasil => $self, entity => $fqn );
}

# get an entity
# FIXME, temporality?
sub get {
    my $class = shift;

    my ($self, $status);
    # If you called this as $entity->get() you wanted fetch().
    if (ref $class) {
	$status = $class->get_status();
	$status->set( 406, "Calling get() as an object method, you probably wanted fetch() to get an instance" );
	return undef;
    } else {
	$self   = $class->SUPER::new(@_);
	$status = $self->get_status();	
    }
    
    my %params = @_;

    my $identifier = $params{entity} || $params{id};
    my @query;
    
    if ($params{entity}) {
	@query = ('entity' => $params{entity});
    } elsif ($params{id}) {
	@query = ('id' => $params{id});
    } else {
	$status->set( 503, "Unable to process query format for Entity lookup." );
	return undef;
    }

    my $aref = $self->storage()->fetch( 'MetaEntity', { where => [ @query ],
							return => [ 'id', 'entity', 'parent', 'start', 'stop' ] } );
    
    unless (defined $aref->[0]->{id}) {
	$status->set( 404, "Entity '$identifier' not found." );
	return undef;
    } 
    
    $status->set( 200 );
    return objectify( name      => $aref->[0]->{entity},
		      parent    => $aref->[0]->{parent},
		      id        => $aref->[0]->{id},
		      start     => $aref->[0]->{start},
		      stop      => $aref->[0]->{stop},
		      yggdrasil => $self->{yggdrasil},
		    );
}

sub objectify {
    my %params = @_;
    
    my $obj = new Yggdrasil::Entity( name => $params{name}, yggdrasil => $params{yggdrasil} );
    $obj->{name}   = $params{name};
    $obj->{_id}    = $params{id};
    $obj->{_start} = $params{start};
    $obj->{_stop}  = $params{stop};
    $obj->{parent}   = $params{parent};
    return $obj;
}

sub undefine {

}

# create instance
sub create {
    my $self = shift;
    my $name = shift;

    return Yggdrasil::Instance->create( yggdrasil => $self,
					entity    => $self,
					id        => $name );
}

# fetch instance
sub fetch {
    my $self  = shift;
    my $name  = shift;

    # FUGLY, FIXME TO WORK!
    my @time;
    for my $t (@_) {
	# If the tick undef or 0, pass it along, we're dealing with
	# semantics here.
	push(@time, $t) and next if ! defined $t || $t == 0;
	my @tick = $self->yggdrasil()->get_ticks_by_time( $t );
	if (@time > 1) {
	    push(@time, $tick[-1]->{id} );
	} else {
	    push(@time, $tick[0]->{id} );
	}
    }

    return Yggdrasil::Instance->fetch( yggdrasil => $self,
				       entity    => $self,
				       id        => $name, 
				       time      => [@time] );
}

# delete instance
sub delete :method {
    my $self = shift;
    my $name = shift;

    return Yggdrasil::Instance->delete( yggdrasil => $self,
					entity    => $self,
					id        => $name );
}

# all instances
sub instances {
    my $self = shift;
    
    my $instances = $self->storage()->fetch( 
	'MetaEntity' => { where  => [ entity => $self->name() ] },
	'Instances'   => { return => [ 'visual_id', 'id' ],
			  where  => [ entity => \qq{MetaEntity.id} ] } );
    
    # FIXME, find a way to create instance objects in a nice way
    my @i;
    for my $i ( @$instances ) {
	my $o = Yggdrasil::Instance->new( yggdrasil => $self );
	$o->{visual_id} = $i->{visual_id};
	$o->{_id}       = $i->{id};
	$o->{entity}    = $self;
	push(@i,$o);
    }

    return @i;
}

sub search {
    my ($self, $key, $value) = (shift, shift, shift);
    
    # Passing the possible time elements onwards as @_ to the Storage layer.
    my ($nodes) = $self->storage()->search( $self->name(), $key, $value, @_);
    
    my @hits;
    for my $hit (@$nodes) {
	my $obj = bless {}, 'Yggdrasil::Instance';
	$obj->{entity}    = $self;
	$obj->{yggdrasil} = $self->{yggdrasil};
	for my $key (keys %$hit) {
	    $obj->{$key} = $hit->{$key};
	}
	push @hits, $obj;
    }
    return @hits;
}

sub name {
    my $self = shift;

    return $self->{name};
}

sub parent {
    my $self = shift;

    return unless $self->{parent};
    return __PACKAGE__->get( id => $self->{parent}, yggdrasil => $self );
}

# Handle property definition and deletion
sub define_property {
    my $self = shift;
    my $name = shift;

    return Yggdrasil::Property->define( yggdrasil => $self, entity => $self, property => $name, @_ );
}

sub undefine_property {

}

sub get_property {
    my $self = shift;
    my $prop = shift;
    return Yggdrasil::Property->get( yggdrasil => $self, entity => $self, property => $prop, @_ );
}

# Handle property queries.  Returns undef or a hash with 'name',
# 'start' and 'stop'.
sub property_exists {
    my ($self, $property) = (shift, shift);
    my ($start, $stop) = get_times_from( @_ );
    
    my $storage = $self->{yggdrasil}->{storage};
    my @ancestors = $self->ancestors($start, $stop);
    
    # Check to see if the property exists.
    foreach my $e ( @ancestors ) {
	my $aref = $storage->fetch(
	    MetaEntity => { 
		where => [ entity => $e ],
	    },
	    MetaProperty => { 
		return => [ 'property', 'start', 'stop' ],
		where  => [ 
		    property => $property,
		    entity   => \q<MetaEntity.id>,
		    ]
	    },

	    { start => $start, stop => $stop });

	# The property name might be "0".
	return { name  => join(":", $e, $property ),
		 start => $aref->[0]->{start},
		 stop  => $aref->[0]->{stop} } if defined $aref->[0]->{property};
    }
    
    return;
}

sub properties {
    my $self = shift;
    my ($start, $stop) = get_times_from( @_ );

    my $storage = $self->{yggdrasil}->{storage};
    my @ancestors = $self->ancestors($start, $stop);
    my %properties;

    foreach my $e ( @ancestors ) {
	my $aref = $storage->fetch(
	    MetaEntity => {
		where => [ entity => $e ]
	    },
	    MetaProperty => {
		return => 'property',
		where  => [ entity => \q<MetaEntity.id> ]
	    },

	    { start  => $start, stop => $stop });


	for my $p (@$aref) {
	    my $eobj;

	    if ($e eq $self->name()) {
		$eobj = $self;
	    } else {
		$eobj = __PACKAGE__->get( entity => $e, yggdrasil => $self->{yggdrasil} );
	    }
	    
	    $properties{ $p->{property} } = Yggdrasil::Property::objectify( name      => $p->{property},
									    yggdrasil => $self->{yggdrasil},
									    entity    => $eobj );
	}
    }

    return sort values %properties;
}

# Word of warnings, ancestors returns *names* not objects.  However,
# this is *probably* acceptable.
sub ancestors {
    my $self  = shift;
    my ($start, $stop) = @_;

    my @ancestors;
    my %seen = ( $self->{_id} => 1 );

    my $storage = $self->storage();
    my $r = $storage->fetch( MetaEntity => { return => [qw/entity parent/],
					     where  => [ id => $self->{_id} ] },
			     { start => $start, stop => $stop });
    
    while( @$r ) {
	my $parent = $r->[0]->{parent};
	my $name   = $r->[0]->{entity};

	if( $parent ) {
	    last if $seen{$parent};
	    $seen{$parent} = 1;
	}

	push( @ancestors, $name );

	last unless $parent;

	$r = $storage->fetch( MetaEntity => { return => [qw/entity parent/],
					      where => [ id => $parent ] },
			      { start => $start, stop => $stop } );
    }

    return @ancestors;
}


sub _admin_dump {
    my $self   = shift;
    my $entity = shift;

    return $self->{storage}->raw_fetch( Instances => { where => [ entity => $entity ] } );
}

sub _admin_restore {
    my $self   = shift;
    my $data   = shift;

    $self->{storage}->raw_store( "Instances", fields => $data );

    my $id = $self->{storage}->raw_fetch( Instances =>
					  { return => "id", 
					    where => [ %$data ] } );
    return $id->[0]->{id};
}


1;
