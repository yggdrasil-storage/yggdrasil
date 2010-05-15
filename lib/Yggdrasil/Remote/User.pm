package Yggdrasil::Remote::User;

use strict;
use warnings;

use base qw/Yggdrasil::User/;

sub get {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;
    
    return Yggdrasil::Object::objectify(
					$self->yggdrasil(),
					__PACKAGE__,
					$self->storage()->{protocol}->get_user( $params{user} ),
				       );
}

sub get_all {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    return Yggdrasil::Object::objectify(
					$self->yggdrasil(),
					__PACKAGE__,
					$self->storage()->{protocol}->get_all_users(),
				       );
}

sub expire {
    my $self = shift;
    my %params = @_;

    $self->storage()->{protocol}->expire_user( $self->id() );
}

sub _setter_getter {
    my $self = shift;
    my $key  = shift;

    if( @_ ) {
	$self->storage()->{protocol}->set_user_value( $self->id(), $key, $_[0] );
	return $_[0];
    }

    return $self->storage()->{protocol}->get_user_value( $self->id(), $key );
}

# Instance-like interface.
sub property {
    my ($self, $key) = (shift, shift);
    
    my $status = $self->get_status();
    my %accepted_properties = (
			       password => 1,
			       session  => 1,
			       cert     => 1,
			       fullname => 1,
			      );

    unless ($accepted_properties{$key}) {
	$status->set( 404, "Users have no property '$key'" );
	return;
    }

    if (@_) {
	return $self->_setter_getter( $key, $_[0] );
    } else {
	return $self->_setter_getter( $key );
    }
    
}

sub password {
    my $self = shift;

    if (@_) {
	return $self->_setter_getter( 'password', $_[0] );
    } else {
	return $self->_setter_getter( 'password' );
    }
}

sub session {
    my $self = shift;

    if (@_) {
	return $self->_setter_getter( 'session', $_[0] );
    } else {
	return $self->_setter_getter( 'session' );
    }
}

sub fullname {
    my $self = shift;

    if (@_) {
	return $self->_setter_getter( 'fullname', $_[0] );
    } else {
	return $self->_setter_getter( 'fullname' );
    }
}

sub cert {
    my $self = shift;

    if (@_) {
	return $self->_setter_getter( 'cert', $_[0] );
    } else {
	return $self->_setter_getter( 'cert' );
    }
}
 
sub username {
    my $self = shift;    
    return $self->id();
}

sub id {
    my $self = shift;
    return $self->{name};
}

sub member_of {
    my $self = shift;
    my @r = $self->storage()->{protocol}->get_roles_of( $self->id() );
    return Yggdrasil::Object::objectify(
					$self->yggdrasil(),
					'Yggdrasil::Remote::Role',
					@r
					);
}

1;
