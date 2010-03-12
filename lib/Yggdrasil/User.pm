package Yggdrasil::User;

# This class acts as a wrapper class for the entity MetaAuthUser.
# It provides a handy interface to defining, getting, undefining users,
# as well as getters and setters for some predefined properties.

use strict;
use warnings;

use base qw(Yggdrasil::Object);

use Yggdrasil::Storage::Auth;
use Yggdrasil::Storage::Auth::User;

sub define {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    # --- Generate a password if one was not passed in
    my $auth = new Yggdrasil::Storage::Auth;
    my $pass = defined $params{password} ? $params{password} : $auth->generate_password();
    my $storage_user = Yggdrasil::Storage::Auth::User->define( $self->{yggdrasil}->{storage},
							       $params{user},
							       $pass,
							     );
 
    $self->{_user_obj} = $storage_user;
    return $self;
}

sub get {
    my $class = shift;
    my $self = $class->SUPER::new( @_ );
    my %params = @_;
    
    my $storage_user;
    if (ref $params{user} eq 'Yggdrasil::Storage::Auth::User') {
	$storage_user = $params{user};
    } elsif (ref $params{user}) {
	Yggdrasil::fatal( "Unexpected reference given to Yggdrasil::User->get()" );
    } else {
	$storage_user = Yggdrasil::Storage::Auth::User->get( $self->{yggdrasil}->{storage}, $params{user} );	
    }
    
    $self->{_user_obj} = $storage_user;

    unless ($self->{_user_obj}) {
	$self->get_status()->set( 404 );
	return;
    }
    return $self;
}

sub get_all {
    my $class = shift;
    my $self  = $class->SUPER::new( @_ );
    my %params = @_;

    my @users;
    for my $user_obj ( Yggdrasil::Storage::Auth::User->get_all( $self->{yggdrasil}->{storage}) ) {
	push( @users, $class->get( yggdrasil => $self, user => $user_obj ) );
    }
    
    return @users;
}

sub start {
    my $self = shift;
    return $self->{_user_obj}->start();
}

sub stop {
    my $self = shift;
    return $self->{_user_obj}->stop();
}

sub expire {
    my $self = shift;
    $self->{_user_obj}->expire();
}

sub _setter_getter {
    my $self = shift;
    my $key  = shift;
    my $val  = shift;

    my $uo = $self->{_user_obj};
    if( defined $val ) {
	$uo->set_field( $key => $val );
	return $val;
    }

    return $uo->get_field( $key );
}

sub password {
    my $self = shift;
    my $value = shift;

    return $self->_setter_getter( password => $value );
}

sub session {
    my $self = shift;
    my $value = shift;

    return $self->_setter_getter( session => $value );
}

sub fullname {
    my $self = shift;
    my $value = shift;

    return $self->_setter_getter( fullname => $value );
}

sub cert {
    my $self = shift;
    my $value = shift;

    return $self->_setter_getter( cert => $value );
}
 
sub username {
    my $self = shift;
    return $self->id();
}

sub id {
    my $self = shift;
    return $self->{_user_obj}->name();
}

sub member_of {
    my $self = shift;
    my @r = $self->{_user_obj}->member_of();

    return map { Yggdrasil::Role->get( yggdrasil => $self, role => $_ ) } @r;
}

1;
