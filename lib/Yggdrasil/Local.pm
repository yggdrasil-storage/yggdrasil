package Yggdrasil::Local;

use strict;
use warnings;

use Storage;

use base qw/Yggdrasil/;

use Yggdrasil::Utilities qw(time_diff);

sub new {
    my $class = shift;
    my %params = @_;

    my $self = {
		status => $params{status},
	       };
    
    return bless $self, $class;
}

sub is_remote { return }
sub is_local { return 1 }

sub bootstrap {
    my $self = shift;
    my %userlist = @_;
    
    my $status = $self->get_status();
    if ($self->{storage}->storage_is_empty()) {
	my %usermap = $self->{storage}->bootstrap( %userlist );
	Yggdrasil::MetaEntity->define( yggdrasil => $self );
	Yggdrasil::MetaRelation->define( yggdrasil => $self );
	Yggdrasil::MetaProperty->define( yggdrasil => $self );

	# MetaEntity was created without 'create' auth rules in order
	# for UNIVERSAL to be created. We then proceed to add 'create'
	# auth rules for MetaEntity now that we have a root entity
	my $universal = $self->define_entity( 'UNIVERSAL' );
	Yggdrasil::MetaEntity->define_create_auth( yggdrasil => $self );

	$self->get_user( 'bootstrap' )->expire();
	$status->set( 200, 'Bootstrap successful.');
	return \%usermap;
    } else {
	$status->set( 406, "Unable to bootstrap, data exists." );
	return;
    }
}

sub connect {
    my $self = shift;
    my %params = @_;

    $self->{storage} = Storage->new( @_, status => $self->{status} );
}

sub login {
    my $self = shift;

    my $storage_user_object = $self->{storage}->authenticate( @_ );
    my $status = $self->get_status();
    if ($status->OK()) {
	$self->{user} = $storage_user_object->name();
	return $self->{user};
    } 
    $status->set( 403, 'Login to Yggdrasil denied.' ) unless $status->message();
    return;
}

sub info {
    my $self = shift;
    return $self->{storage}->info();
}

sub protocols {
    my $self = shift;
    return;
}

sub whoami {
    my $self = shift;    
    return $self->user();
}

sub server_data {
    my $self = shift;
    return $self->{storage}->info();
}

# FIXME, generalize out the call to the uptime string.  See also
# POE::Component::Server::Yggdrasil::Interface.pm
sub uptime {
    my $self = shift;    
    my $runtime = time_diff( $^T );
    return "Client uptime: $runtime ($^T) / Server uptime: $runtime ($^T)";
}

sub property_types {
    my $self = shift;

    return $self->{storage}->get_defined_types();
}

sub get_ticks_by_time {
    my $self = shift;

    # We need to feed the backend something it can use, and they like
    # working with all sorts of weird stuff, but we'll delegate that
    # to the storage layer.
    return $self->{storage}->get_ticks_from_time( @_ );
}

sub get_current_tick {
    my $self = shift;
    return $self->{storage}->get_current_tick();
}

sub get_ticks {
    my $self  = shift;
    
    # FIXME, return the 'stamp' field in an ISO date format.
    my $fetchref = $self->{storage}->get_ticks( @_ );
    unless( $fetchref && @$fetchref ) {
	$self->{status}->set( 400, 'Tick not found' );
	return;
    }

    return @$fetchref;
}

# I think I'll call this "proof of concept".  It works well enough for
# the user, but we really need to clean some API here and there.  The
# weird thing, it's fast.  Also, we're passing yggdrasil along as we
# don't want objects to be created with an Yggdrasil::Local as their
# Ygg -- this would break calls to use that Ygg object via
# $ygg->{mode} (which would be unset).  A better way might be to have
# $ygg->mode() and have that check ref $self to see if the choice is
# already made?
sub search {
    my $self = shift;
    my %params = @_;

    my $storage = $self->{storage};
    my $target = $params{search};
    my $ygg    = $params{yggdrasil};
    
    my $time = ();
    $time = $params{time} if $params{time};

    unless (defined $target) {
	$self->get_status()->set( 406, "No search target" );
	return;
    }
    
    my $operator = 'LIKE';
    $operator    = '=' if $params{exact};

    my @entities;
    my $ref = $storage->fetch('MetaEntity', { where  => [ entity => $target ],
					      operator => $operator,
					      return   => '*' },
			      $time);
    for my $hit (@$ref) {
	push( @entities, Yggdrasil::Local::Entity::objectify(
							     name      => $hit->{entity},
							     parent    => $hit->{parent},
							     yggdrasil => $ygg,
							     id        => $hit->{id},
							     start     => $hit->{start},
							     stop      => $hit->{stop},
							    ));
    }

    # Funny warning.  Caching entities based on their userland_id
    # isn't viable.  When searching for 'hey', we may get multiple
    # entities that just differ temporally.  Also, we can't just grab
    # one of these from a "cache" based on their name alone, and know
    # which one of these an instance "heyhey" (which we found later)
    # existed within.  Temporality is tricky, and the solution is to
    # move the cache lower, not higher.  Oh, and creating instances
    # and properties sucks.  We have no way to access either without
    # going through entities, which'd mean creating one of each entity
    # *then* applying this query to each and every one of those.
    # That's hardly viable.
    my @instances;
    $ref = $storage->fetch('MetaEntity', { where  => [ id => \qq<Instances.entity>] },
			   'Instances',  { where    => [ visual_id => $target ],
					   operator => $operator,
					   return   => '*' },
			   $time);
    for my $hit (@$ref) {
	# Oh god.
	my $o = Yggdrasil::Local::Instance->new( yggdrasil => $ygg );
	my $entity = Yggdrasil::Local::Entity->get( yggdrasil => $ygg, id => $hit->{entity}, time => $time );
	$o->{visual_id} = $hit->{visual_id};
	$o->{_id}       = $hit->{id};
	$o->{_start}    = $hit->{start};
	$o->{_stop}     = $hit->{stop};
	$o->{entity}    = $entity;	  
	push (@instances, $o );
    }

    # Right, that was effin' ugly.  Let's do it again, just slightly
    # differently.  Yay!  Btw, does anyone have a consistent API to
    # sell?  I think we're buying.
    my @properties;
    $ref = $storage->fetch('MetaEntity', { where  => [ id => \qq<MetaProperty.entity>],
					   return => 'entity',
					 },
			   'MetaProperty', { where    => [ property => $target ],
					     operator => $operator,
					     return   => '*' },
			   $time );
    for my $hit (@$ref) {
	my $entity = Yggdrasil::Local::Entity->get( yggdrasil => $ygg, id => $hit->{entity}, time => $time );
	push( @properties, Yggdrasil::Local::Property::objectify(
								 name      => $hit->{property},
								 entity    => $entity,
								 yggdrasil => $ygg,
								 id        => $hit->{id},
								 start     => $hit->{start},
								 stop      => $hit->{stop},
								));
    }

    $ref = $storage->fetch('MetaRelation', { where  => [ label => $target ],
					     operator => $operator,
					     return   => '*' },
			   $time );
    my @relations;
    for my $hit (@$ref) {
	my $lval = Yggdrasil::Local::Entity->get( yggdrasil => $ygg, id => $hit->{lval}, time => $time );
	my $rval = Yggdrasil::Local::Entity->get( yggdrasil => $ygg, id => $hit->{rval}, time => $time );
	push( @relations, Yggdrasil::Local::Relation::objectify(
								label     => $hit->{label},
								id        => $hit->{id},
								start     => $hit->{start},
								stop      => $hit->{stop},
								lval      => $lval,
								rval      => $rval,
								yggdrasil => $ygg,
							       ));
    }

    $self->get_status()->set( 200 );
    return \@entities, \@instances, \@properties, \@relations;
}

sub transaction_stack_get {
    my $self = shift;
    return $self->{storage}->{transaction}->get_stack();
}

sub transaction_stack_clear {
    my $self = shift;
    return $self->{storage}->{transaction}->clear_stack();
}


1;
