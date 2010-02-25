package Yggdrasil::Entity;

use strict;
use warnings;

use base qw(Yggdrasil::Object);

use Yggdrasil::Entity::Instance;

use Yggdrasil::MetaEntity;
use Yggdrasil::MetaInheritance;

use Yggdrasil::Property;

use Yggdrasil::Utilities qw|get_times_from|;
  
sub define {
    my $class  = shift;
    my $self   = $class->SUPER::new( @_ );
    my %params = @_;

    my $name   = $params{entity};
    my $parent = $params{inherit};

    my $fqn = $parent ? join('::', $parent, $name) : $name;

    my @entities = split m/::/, $fqn;
    if (@entities > 1) {
	$name   = pop @entities;
	$parent = join('::', @entities);

	if ($self->{yggdrasil}->{strict}) { # How about $self->strict() 
                                            # (with strict() living in Y::Object)
	    if( ! Yggdrasil::Entity->get( yggdrasil => $self, entity => $parent)  ) {
	    #if (! $self->{yggdrasil}->get_entity( $parent )) {
		my $status = $self->get_status();
		$status->set( 400, "Unable to access parent entity $parent." );
		return;
	    }
	} else {
	    # print " ** Create $fqn\n";
	}
    }
    $self->{name} = $fqn;

    # --- Add to MetaEntity, noop if it exists.
    Yggdrasil::MetaEntity->add( yggdrasil => $self, entity => $fqn );
    #$self->_meta_add($fqn);

    my $status = $self->get_status();
    return unless $status->OK();

    $self = __PACKAGE__->get( yggdrasil => $self, entity => $fqn );

    # --- Update MetaInheritance  
    if( defined $parent ) {
	$parent = __PACKAGE__->get( yggdrasil => $self, entity => $parent );
	Yggdrasil::MetaInheritance->add( yggdrasil => $self, child => $self, parent => $parent );
	#$self->_add_inheritance( $fqn, $parent );
    } else {
	# warnings, this does update, which sets status.
	#$self->_expire_inheritance( $fqn );
	Yggdrasil::MetaInheritance->expire( yggdrasil => $self, entity => $self );
    }

    return $self;
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

    my $entity = $params{entity};
    
    my $aref = $self->storage()->fetch( 'MetaEntity', { where => [ entity => $entity ],
							return => [ 'id', 'start', 'stop' ] } );
    
    unless (defined $aref->[0]->{id}) {
	$status->set( 404, "Entity '$entity' not found." );
	return undef;
    } 
    
    $status->set( 200 );
    return objectify( name  => $entity,
		      id    => $aref->[0]->{id},
		      start => $aref->[0]->{start},
		      stop  => $aref->[0]->{stop},
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
    return $obj;
}

sub undefine {

}

# create instance
sub create {
    my $self = shift;
    my $name = shift;

    return Yggdrasil::Entity::Instance->create( yggdrasil => $self,
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

    return Yggdrasil::Entity::Instance->fetch( yggdrasil => $self,
					       entity    => $self,
					       id        => $name, 
					       time      => [@time] );
}

# delete instance
sub delete :method {
    my $self = shift;
    my $name = shift;

    return Yggdrasil::Entity::Instance->delete( yggdrasil => $self,
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
	my $o = Yggdrasil::Entity::Instance->new( yggdrasil => $self );
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
	my $obj = bless {}, 'Yggdrasil::Entity::Instance';
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
    foreach my $e ( $self->name(), @ancestors ) {
	my $aref = $storage->fetch('MetaEntity', { where => [ id     => \qq{MetaProperty.entity},
							      entity => $e,
							    ]},
				   'MetaProperty', { return => [ 'property', 'start', 'stop' ],
						     where => [ property => $property ] },
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
    
    foreach my $e ( $self->name(), @ancestors ) {
	my $aref = $storage->fetch('MetaEntity', { where => [ id     => \qq{MetaProperty.entity},
							      entity => $e,
							    ]},
				   'MetaProperty', 
				    { return => 'property' },
				    { start  => $start, stop => $stop });


	for my $p (@$aref) {
	    my $eobj;

	    if ($e eq $self->name()) {
		$eobj = $self;
	    } else {
		$eobj = Yggdrasil::Entity::objectify( name => $e, yggdrasil => $self->{yggdrasil} );
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
    my $r = $storage->fetch( MetaInheritance => { return => "parent", where => [ child => $self->{_id} ] },
			     MetaEntity => { return => "entity", where => [ id => \q<MetaInheritance.parent> ] },
			     { start => $start, stop => $stop });
    
    while( @$r ) {
	my $parent = $r->[0]->{parent};
	my $name   = $r->[0]->{entity};

	last if $seen{$parent};
	$seen{$parent} = 1;
	push( @ancestors, $name );

	$r = $storage->fetch( MetaInheritance => { return => "parent", where => [ child => $parent ] },
			      MetaEntity => { return => "entity", where => [ id => \q<MetaInheritance.parent> ] },
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
