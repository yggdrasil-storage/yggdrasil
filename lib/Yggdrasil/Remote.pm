package Yggdrasil::Remote;

use strict;
use warnings;

use base qw/Yggdrasil/;

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

    $self->{client} = new Yggdrasil::Interface::Client( status => $self->{status} );
    $self->{client}->connect( @_ );
}

sub login {
    my $self = shift;

    return $self->{client}->login( @_ );
}

sub info {
    my $self = shift;

    return $self->{client}->info();
}

sub property_types {

}

sub get_ticks_by_time {

}

sub get_ticks {
}

sub transaction_stack_get {
}

sub transaction_stack_clear {
}

1;
