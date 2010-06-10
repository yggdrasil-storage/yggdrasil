package Yggdrasil::Remote;

use strict;
use warnings;

use base qw/Yggdrasil/;

use Yggdrasil::Remote::Client;

sub new {
    my $class = shift;
    my %params = @_;

    my $self = {
		status => $params{status},
	       };
    
    return bless $self, $class;
}

sub is_remote { return 1 }
sub is_local { return }

sub bootstrap {
    die;
}

sub connect {
    my $self = shift;

    $self->{storage} = Yggdrasil::Remote::Client->new( status => $self->{status} );
    $self->{storage}->connect( @_ );
}

sub login {
    my $self = shift;

    return $self->{storage}->login( @_, protocol => 'XML' );
}

sub protocols {
    my $self = shift;
    return $self->{storage}->protocols();
}

sub info {
    my $self = shift;
    return $self->{storage}->{protocol}->info();
}

sub whoami {
    my $self = shift;
    return $self->{storage}->{protocol}->whoami();
}

sub uptime {
    my $self = shift;
    return $self->{storage}->{protocol}->uptime();
}

sub server_data {
    my $self = shift;
    return $self->{storage}->server_data();    
}

sub property_types {
    my $self = shift;
    return $self->{storage}->{protocol}->property_types();   
}

sub get_current_tick {
    my $self = shift;
    return $self->{storage}->{protocol}->get_current_tick();
}

sub get_ticks_by_time {
    my $self = shift;
    return $self->{storage}->{protocol}->get_ticks_by_time( @_ );    
}

sub get_ticks {
    my $self = shift;
    return $self->{storage}->{protocol}->get_ticks( @_ );
}

sub get_tick {
    my $self = shift;
    return $self->{storage}->{protocol}->get_ticks( shift );
}


sub transaction_stack_get {

}

sub transaction_stack_clear {
    
}

1;
