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
    if ($self->{storage}->yggdrasil_is_empty()) {
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
    $self->{user} = $storage_user_object->name() if $storage_user_object;
    return $self->{user};
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

sub get_ticks {
    my $self  = shift;
    my @ticks;
    
    for my $t (@_) {
	push @ticks, 'id' => $t;
    }
    
    # FIXME, return the 'stamp' field in an ISO date format.
    my $fetchref = $self->{storage}->fetch( 'Storage_ticker', { return => [ 'id', 'stamp', 'committer' ],
								where  => [ @ticks ],
								bind   => 'or',
							      } );
    
    if (! $fetchref->[0]->{stamp}) {
	$self->{status}->set( 400, 'Tick not found' );
	return undef;
    }

    return @$fetchref;
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
