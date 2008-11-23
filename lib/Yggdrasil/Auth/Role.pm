package Yggdrasil::Auth::Role;

use strict;
use warnings;

use base qw(Yggdrasil::Entity::Instance);

sub grant {
    my $self   = shift;
    my $schema = shift;
    my $grant  = shift;
}

sub revoke {
    my $self   = shift;
    my $schema = shift;
    my $grant  = shift;
}

sub add {
    my $self = shift;
    my $user = shift;

    $self->{storage}->store( "MetaAuthRolemembership",
			     key => [ qw/role user/ ],
			     fields => { role => $self->{_id},
					 user => $user->{_id},
			     } );
}

sub remove {
    my $self = shift;
    my $user = shift;

    $self->{storage}->expire( "MetaAuthRolemembership",
			      role => $self->{_id},
			      user => $user->{_id} );
}

1;
