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

    my $transaction = $self->storage()->initialize_transaction();

    my $parent_id = undef;
    my $pentity;
    
    my $status = $self->get_status();
    if( defined $parent ) {
	$pentity = Yggdrasil::Local::Entity->get( yggdrasil => $self,
						     entity    => $parent );

	unless( $pentity ) {
	    $status->set( 400, "Unable to access parent entity $parent." );
	    $transaction->rollback();
	    return;
	}

	$parent_id = $pentity->_internal_id();
    }

    if ($parent_id && $parent_id != 1) {
	$fqn = join "::", $pentity->id(), $name;
    } else {
	$fqn = $name;
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

    unless ($status->OK()) {
	$transaction->rollback();
	return;
    }
    
    my $o = __PACKAGE__->get( yggdrasil => $self, entity => $fqn );

    $transaction->commit();
    return $o;
    
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
    my $time = $params{time} || {};

    my $identifier = $params{entity} || $params{id};
    my @query;
    
    if ($params{entity}) {
	$params{entity} =~ s/^UNIVERSAL:://;
	@query = ('entity' => $params{entity});
    } elsif ($params{id}) {
	@query = ('id' => $params{id});
    } else {
	$status->set( 503, "Unable to process query format for Entity lookup." );
	return undef;
    }

    my $aref = $self->storage()->fetch( 'MetaEntity', { where => [ @query ],
							return => [ 'id', 'entity', 'parent', 'start', 'stop' ] },
					$time,
				      );
    
    unless (defined $aref->[0]->{id}) {
	$status->set( 404, "Entity '$identifier' not found." );
	return undef;
    } 
    
    $status->set( 200 );
    my @objs = map { objectify( name      => $_->{entity},
				parent    => $_->{parent},
				id        => $_->{id},
				realstart => $_->{start},
				realstop  => $_->{stop},
				start     => $time->{start} || $_->{start},
				stop      => $time->{stop} || $_->{stop},
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
    
    my $time = $params{time} || {};
    if( exists $time->{stop} && ! defined $time->{stop} ) {
	$time->{stop} = $self->yggdrasil()->current_tick();
    }

    my $aref = $self->storage()->fetch( MetaEntity => { return => [ 'id', 'entity', 'parent', 'start', 'stop' ] },
					$time,
				      );

    return map { objectify( name      => $_->{entity},
			    parent    => $_->{parent},
			    id        => $_->{id},
			    realstart => $_->{start},
			    realstop  => $_->{stop},
			    start     => $time->{start} || $_->{start},
			    stop      => $time->{stop} || $_->{stop},
			    yggdrasil => $self->{yggdrasil},
			  ) } @$aref;
}

sub objectify {
    my %params = @_;
    
    my $obj = new Yggdrasil::Local::Entity( name => $params{name}, yggdrasil => $params{yggdrasil} );
    $obj->{name}       = $params{name};
    $obj->{_id}        = $params{id};
    $obj->{_start}     = $params{start};
    $obj->{_stop}      = $params{stop};
    $obj->{_realstart} = $params{realstart};
    $obj->{_realstop}  = $params{realstop};
    $obj->{parent}     = $params{parent};
    return $obj;
}

sub expire {
    my $self = shift;

    my $status  = $self->get_status();
    my $storage = $self->storage();

    my $transaction = $storage->initialize_transaction();
    
    # Do not expire historic Entities
    if( $self->stop() ) {
	$status->set( 406, "Unable to expire historic entity" );
	$transaction->rollback();
	return;
    }

    # Do not expire UNIVERSAL.  That's bad.
    if ($self->_internal_id() == 1) {
	$status->set( 403, "Unable to expire the root entity, 'UNIVERSAL'");
	$transaction->rollback();
	return;
    }
    
    # Expire all descendants first
    for my $child ($self->children()) {
	$child->expire();
    }

    # Expire all relevant relations
    for my $relation ($self->relations(level=>1)) {
	$relation->expire();
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
	$transaction->commit();
	return 1;
    } else {
	$transaction->rollback();
	return;
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

    my (@filter, @operators);
    if ($params{search}) {
	@filter    = ( visual_id => $params{search} );
	my $operator = 'LIKE';
	$operator    = '=' if $params{exact};
	@operators = ( operator  => [ '=', $operator ] );
    }
    
    my $instances = $self->storage()->fetch( 
	MetaEntity => { where  => [ entity => $self->_userland_id() ] },
	Instances  => { return => [ 'visual_id', 'id', 'start', 'stop' ],
			where  => [
				   entity => \qq{MetaEntity.id},
				   @filter,
				  ],
			@operators,
		      },
	$time );
    
    # FIXME, find a way to create instance objects in a nice way
    my @i;
    for my $i ( @$instances ) {
	my $o = Yggdrasil::Local::Instance->new( yggdrasil => $self );
	$o->{visual_id}  = $i->{visual_id};
	$o->{_start}     = $time->{start} || $i->{start};
	$o->{_stop}      = $time->{stop} || $i->{stop};
	$o->{_realstart} = $i->{start};
	$o->{_realstop}  = $i->{stop};
	$o->{_id}        = $i->{id};
	$o->{entity}     = $self;
	push(@i,$o);
    }

    return @i;
}

sub find_instances_by_name {
    my $self = shift;
    my $key  = shift;

    return $self->instances( search => $key, @_ );
}

sub find_instances_by_property_value {
    my $self   = shift;
    my %params = @_;

    my $time = $self->_validate_temporal( $params{time} ); 
    return unless $time;

    my $status = $self->get_status();

    for my $p (qw|key value|) {
	unless (defined $params{$p}) {
	    $status->set( 400, "Missing the required parameter '$p'" );
	    return;
	}
    }
    
    # Pass along temporality.  If we don't get a proper property
    # object in return, it didn't exist at the given time (which may
    # be NOW()).
    my $prop = $self->get_property( $params{key}, time => $time );
    return unless $self->get_status()->OK();

    my $schema = $prop->full_name();

    my $operator = 'LIKE';
    $operator = '=' if $params{exact};
    
    my $hits = $self->storage()->fetch( $schema => { where    => [ value => $params{value} ],
						     return   => [ 'value' ],			     
						     operator => $operator },
					Instances  => { return => [ 'visual_id', 'id', 'start', 'stop' ],
							where  => [ id => \qq{$schema.id} ] },
					$time );
    
    # FIXME, find a way to create instance objects in a nice way
    my @i;
    for my $i ( @$hits ) {
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
	return { name      => join(":", $e, $property ),
		 id        => $aref->[0]->{id},
		 realstart => $aref->[0]->{start},
		 realstop  => $aref->[0]->{stop},
		 start     => $time->{start} || $aref->[0]->{start},
		 stop      => $time->{stop} || $aref->[0]->{stop} } 
	  if defined $aref->[0]->{property};
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
							       start     => $time->{start} || $p->{start},
							       stop      => $time->{stop} || $p->{stop},
							       realstart => $p->{start},
							       realstop  => $p->{stop},
							       entity    => $eobj );
	}
    }

    return sort { $a->_userland_id() cmp $b->_userland_id() } @rets;
}

sub relations {
    my $self = shift;
    my %params = @_;

    my $time = $self->_validate_temporal( $params{time} );
    return unless $time;

    my $storage = $self->{yggdrasil}->{storage};
    my @ancestors = $self->ancestors( $time );

    # Only go N-levels deep. level==1 retains only the first ancestor
    # which is yourself, level==2 retains yourself + 1, and so on.
    splice( @ancestors, $params{level} ) if $params{level};
    
    my @rets;
    
    my $aref = $storage->fetch(
	    MetaEntity => {
		where => [ entity => \@ancestors ]
	    },
	    MetaRelation => {
		return => [ 'label', 'id', 'start', 'stop', 'rval', 'lval' ],
		where  => [
			   lval => \q<MetaEntity.id>,
			   rval => \q<MetaEntity.id>,
			  ],
		bind => 'or',
	    },
	    $time );

    for my $o (@$aref) {
	my ($lval, $rval) = (Yggdrasil::Local::Entity->get( id => $o->{lval}, yggdrasil => $self->yggdrasil(), time => $time ),
			     Yggdrasil::Local::Entity->get( id => $o->{rval}, yggdrasil => $self->yggdrasil(), time => $time ));
	
	push @rets, Yggdrasil::Local::Relation::objectify( label     => $o->{label},
							   yggdrasil => $self->{yggdrasil},
							   id        => $o->{id},
							   start     => $time->{start} || $o->{start},
							   stop      => $time->{stop} || $o->{stop},
							   realstart => $o->{start},
							   realstop  => $o->{stop},
							   lval      => $lval,
							   rval      => $rval,
							 );
    }

    return sort { $a->_userland_id() cmp $b->_userland_id() } @rets;
}

# Word of warnings, ancestors returns *names* not objects.  However,
# this is *probably* acceptable.  The source entity is included in the
# returned array (ie, X is an ancestor of X).
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


sub descendants {
    my $self = shift;
    my $time = shift;

    my $storage = $self->storage();
    my $r = $storage->fetch( MetaEntity => { return => [qw/id entity parent/],
					     where  => [ parent => $self->_internal_id() ] },
			     $time );

    my @descendants;
    my @children = @$r;
    while( @children ) {
	my $child = shift @children;
	my $child_id = $child->{id};
	push( @descendants, $child->{entity} );

	$r = $storage->fetch( MetaEntity => { return => [qw/id entity parent/],
					      where  => [ parent => $child_id ] },
			      $time );

	push( @children, @$r );
    }

    return @descendants;
}

sub children {
    my $self = shift;
    my $time = shift;

    my $storage = $self->storage();
    my $r = $storage->fetch( MetaEntity => { return => [qw/id entity parent/],
					     where  => [ parent => $self->_internal_id() ] },
			     $time );

    my @children;
    foreach my $child (@$r) {
	push( @children, __PACKAGE__->get(yggdrasil => $self, entity => $child->{entity}) );
    }

    return @children;
}

1;
