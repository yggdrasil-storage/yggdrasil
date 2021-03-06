package Yggdrasil::Object;

use strict;
use warnings;

sub new {
    my $class = shift;
    if( ref $class ) {
	my $status = $class->get_status();
	$status->set( 406, "Calling new() as an object method, you probably wanted create() instead" );
	return undef;
    }
    
    my $self  = bless {}, $class;

    if( @_ % 2 ) { 
	print "ARGS: (", join(", ", @_), ")\n"; 
	Yggdrasil::fatal("Odd number of elements in hash assignment");
    }

    my %params = @_;

    $self->{yggdrasil} = $params{yggdrasil}->yggdrasil();

    return $self;
}

sub yggdrasil {
    my $self = shift;

    unless( ref $self ) {
	Yggdrasil::fatal( "\$self is not a reference ($self)" );
    }
    return $self->{yggdrasil};
}

sub storage {
    my $self = shift;

    return $self->yggdrasil()->{storage};
}

sub get_status {
    my $self = shift;
    return $self->{yggdrasil}->{status};
}

sub start {
    my $self = shift;
    return $self->{_start};
}

sub stop {
    my $self = shift;
    return $self->{_stop};
}

sub realstart {
    my $self = shift;
    return $self->{_realstart};
}

sub realstop {
    my $self = shift;
    return $self->{_realstop};
}

sub can_read {
    return 1;
}

sub objectify {
    my ($ygg, $package, @refs) = @_;
    my @set = map { $_->{yggdrasil} = $ygg; bless $_, $package; } grep { defined } @refs;

    return unless @set;
    
    if (wantarray) {
	return @set;
    } else {
	return $set[0];
    }    
}

# FIXME: The remote API seems to create some objects without a proper
# self->start() set, so until that's fixed, we'll have to test for the
# existance of self->start() in the code below.  This shouldn't be
# needed, *ever*, but seemlingly is for some reason.  It's odd that
# this is the only place this breaks.
sub _validate_temporal {
    my $self = shift;
    my $time = shift || {};

    # START
    my $invalid = 0;
    if( defined $time->{start} ) {
	$invalid = "'start' out of range" if $self->start() && $time->{start} < $self->start();
	$invalid = "'start' out of range" if $self->stop() && $time->{start} > $self->stop();
    }

    my $start = $time->{start} || $self->start();

    # STOP
    if( exists $time->{stop} ) {
	if( defined $time->{stop} ) {
	    $invalid = "'stop' out of range" if $self->start() && $time->{stop} < $self->start();
	    $invalid = "'stop' out of range" if $self->stop() && $time->{stop} > $self->stop();
	} else {
	    # user specified 'stop', but value was 'undef'. This means
	    # that the user has requested a slice from 'start' to
	    # 'current', 
	    $time->{stop} = $self->yggdrasil()->current_tick();
	}
    }

    my $stop = $time->{stop} || $self->stop();

    if( $invalid ) {
	$self->get_status()->set( 406, $invalid );
	return;
    }

    # If we're calling _validate_temporal on an object that has just
    # been created via Object::new (SUPER::new() in the code), and we
    # haven't passed any time params, there is no start, no stop and
    # it's all current.
    if( $stop || ( $start && $start != $self->start() )) {
	return { start => $start, stop => $stop };
    }

    return {};
}

# Core internal ID retrieval. 
sub _internal_id {
    my $self = shift;

    if ($self->{_id}) {
	return $self->{_id};
    } else {
	Yggdrasil::fatal( 'Internal identifier missing' );
    }
}

1;
