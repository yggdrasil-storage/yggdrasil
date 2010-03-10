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
	Yggdrasil::fatal( "\$self not ref ($self)\n" );
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

1;
