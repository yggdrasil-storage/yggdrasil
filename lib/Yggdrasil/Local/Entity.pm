package Yggdrasil::Local::Entity;

use strict;
use warnings;

use Yggdrasil::Local::Instance;
use Yggdrasil::MetaEntity;
use Yggdrasil::Local::Property;

use Yggdrasil::Utilities qw|get_times_from|;

use base qw/Yggdrasil::Entity/;

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
	my $pentity = Yggdrasil::Local::Entity->get( yggdrasil => $self,
						     entity    => $parent );

	unless( $pentity ) {
	    $status->set( 400, "Unable to access parent entity $parent." );
	    return;
	}

	$parent_id = $pentity->_internal_id();
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
sub get {
    my $class = shift;

    my ($self, $status);
    # If you called this as $entity->get() you wanted fetch().
    if (ref $class) {
	return $class->fetch( @_ );
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
							return => [ 'id', 'entity', 'parent', 'start', 'stop' ] },
					$params{time},
				      );
    
    unless (defined $aref->[0]->{id}) {
	$status->set( 404, "Entity '$identifier' not found." );
	return undef;
    } 
    
    $status->set( 200 );
    my @objs = map { objectify( name      => $_->{entity},
				parent    => $_->{parent},
				id        => $_->{id},
				start     => $_->{start},
				stop      => $_->{stop},
				yggdrasil => $self->{yggdrasil},
			      ) } @$aref;
    if (wantarray) {
	return @objs;
    } else {
	return $objs[-1];
    }
    
}

sub get_all {
    my $class  = shift;
    my $self   = $class->SUPER::new( @_ );
    my %params = @_;
    
    my $aref = $self->storage()->fetch( MetaEntity => { return => [ 'id', 'entity', 'parent', 'start', 'stop' ] },
					$params{time},
				      );

    return map { objectify( name      => $_->{entity},
			    parent    => $_->{parent},
			    id        => $_->{id},
			    start     => $_->{start},
			    stop      => $_->{stop},
			    yggdrasil => $self->{yggdrasil},
			  ) } @$aref;
}

sub objectify {
    my %params = @_;
    
    my $obj = new Yggdrasil::Local::Entity( name => $params{name}, yggdrasil => $params{yggdrasil} );
    $obj->{name}    = $params{name};
    $obj->{_id}     = $params{id};
    $obj->{_start}  = $params{start};
    $obj->{_stop}   = $params{stop};
    $obj->{parent}  = $params{parent};
    return $obj;
}

sub expire {
    my $self = shift;

    my $status  = $self->get_status();
    my $storage = $self->storage();

    # Do not expire historic Entities
    if( $self->stop() ) {
	$status->set( 406, "Unable to expire historic entity" );
	return 0;
    }

    # Do not expire UNIVERSAL.  That's bad.
    if ($self->_internal_id() == 1) {
	$status->set( 403, "Unable to expire the root entity, 'UNIVERSAL'");
	return 0;
    }
    
    # Expire all instances
    for my $instance ($self->instances()) {
	$instance->expire();
    }

    # Expire all properties
    for my $property ($self->properties()) {
	$property->expire() if
	  $property->entity()->_internal_id() == $self->_internal_id();
    }

    $storage->expire( 'MetaEntity', id => $self->_internal_id() );

    if ($status->OK()) {
	return 1;
    } else {
	return 0;
    }
}

# create instance
sub create {
    my $self = shift;
    my $name = shift;

    return Yggdrasil::Local::Instance->create( yggdrasil => $self,
					       entity    => $self,
					       instance  => $name );
}

# fetch instance
sub fetch {
    my $self   = shift;
    my $name   = shift;
    my %params = @_;

    return Yggdrasil::Local::Instance->fetch( yggdrasil => $self,
					      entity    => $self,
					      instance  => $name, 
					      time      => $params{time}, );
}

# all instances
sub instances {
    my $self   = shift;
    my %params = @_;
    
    my $time = $self->_validate_temporal( $params{time} ); 
    return unless $time;

    my $instances = $self->storage()->fetch( 
	MetaEntity => { where  => [ entity => $self->_userland_id() ] },
	Instances  => { return => [ 'visual_id', 'id', 'start', 'stop' ],
			where  => [ entity => \qq{MetaEntity.id} ] },
	$time );
    
    # FIXME, find a way to create instance objects in a nice way
    my @i;
    for my $i ( @$instances ) {
	my $o = Yggdrasil::Local::Instance->new( yggdrasil => $self );
	$o->{visual_id} = $i->{visual_id};
	$o->{_start}    = $i->{start};
	$o->{_stop}     = $i->{stop};
	$o->{_id}       = $i->{id};
	$o->{entity}    = $self;
	push(@i,$o);
    }

    return @i;
}

sub search {
    my ($self, $key, $value) = (shift, shift, shift);
    
    # Passing the possible time elements onwards as @_ to the Storage layer.
    my ($nodes) = $self->storage()->search( $self->_userland_id(), $key, $value, @_);
    
    my @hits;
    for my $hit (@$nodes) {
	my $obj = bless {}, 'Yggdrasil::Local::Instance';
	$obj->{entity}    = $self;
	$obj->{yggdrasil} = $self->{yggdrasil};
	for my $key (keys %$hit) {
	    $obj->{$key} = $hit->{$key};
	}
	push @hits, $obj;
    }
    return @hits;
}

sub can_write {
    my $self = shift;
    
    return unless $self->stop();
    return $self->storage()->can( update => 'MetaEntity', { id => $self->_internal_id() } );
}

sub can_expire {
    my $self = shift;
    
    return unless $self->stop();
    return $self->storage()->can( expire => 'MetaEntity', { id => $self->_internal_id() } );
}

sub can_instanciate {
    my $self = shift;

    return $self->storage()->can( create => 'Instances', { entity => $self->_internal_id() } );
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

    return Yggdrasil::Local::Property->define( yggdrasil => $self, entity => $self, property => $name, @_ );
}

sub undefine_property {
    my $self = shift;
    my $prop = shift;
    
    my $propobj = $self->get_property( $prop );
    return $propobj->expire() if $propobj;    
    return;
}

sub get_property {
    my $self = shift;
    my $prop = shift;
    return Yggdrasil::Local::Property->get( yggdrasil => $self, entity => $self, property => $prop, @_ );
}

# Handle property queries.  Returns undef or a hash with 'name',
# 'start' and 'stop'.
sub property_exists {
    my ($self, $property) = (shift, shift);
    my %params = @_;
    
    my $time = $self->_validate_temporal( $params{time} );
    return unless $time;

    my $storage = $self->{yggdrasil}->{storage};
    my @ancestors = $self->ancestors( $time );
    
    # Check to see if the property exists.
    foreach my $e ( @ancestors ) {
	my $aref = $storage->fetch(
	    MetaEntity => { 
		where => [ entity => $e ],
	    },
	    MetaProperty => { 
		return => [ 'id', 'property', 'start', 'stop' ],
		where  => [ 
		    property => $property,
		    entity   => \q<MetaEntity.id>,
		    ]
	    },

	    $time );

	# The property name might be "0".
	return { name  => join(":", $e, $property ),
		 id    => $aref->[0]->{id},
		 start => $aref->[0]->{start},
		 stop  => $aref->[0]->{stop} } if defined $aref->[0]->{property};
    }
    
    return;
}

sub properties {
    my $self = shift;
    my %params = @_;
    
    my $time = $self->_validate_temporal( $params{time} );
    return unless $time;

    my $storage = $self->{yggdrasil}->{storage};
    my @ancestors = $self->ancestors( $time );
    my @rets;

    foreach my $e ( @ancestors ) {
	my $aref = $storage->fetch(
	    MetaEntity => {
		where => [ entity => $e ]
	    },
	    MetaProperty => {
		return => [ 'property', 'id', 'start', 'stop' ],
		where  => [ entity => \q<MetaEntity.id> ]
	    },
	    $time );

	for my $p (@$aref) {
	    my $eobj;

	    if ($e eq $self->_userland_id()) {
		$eobj = $self;
	    } else {
		$eobj = __PACKAGE__->get( entity => $e, yggdrasil => $self->{yggdrasil} );
	    }
	    
	    push @rets, Yggdrasil::Local::Property::objectify( name      => $p->{property},
							       yggdrasil => $self->{yggdrasil},
							       id        => $p->{id},
							       start     => $p->{start},
							       stop      => $p->{stop},
							       entity    => $eobj );
	}
    }

    return sort { $a->_userland_id() cmp $b->_userland_id() } @rets;
}

# Word of warnings, ancestors returns *names* not objects.  However,
# this is *probably* acceptable.
sub ancestors {
    my $self = shift;
    my $time = shift;

    my @ancestors;
    my %seen = ( $self->_internal_id() => 1 );

    my $storage = $self->storage();
    my $r = $storage->fetch( MetaEntity => { return => [qw/entity parent/],
					     where  => [ id => $self->_internal_id() ] },
			     $time );
    
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
			      $time );
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
