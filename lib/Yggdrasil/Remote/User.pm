package Yggdrasil::Remote::User;

use strict;
use warnings;

use base qw/Yggdrasil::User/;

sub get {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    my $dataref = $self->storage()->{protocol}->get_user( $params{user} );
    return unless $dataref;
    return bless $dataref, __PACKAGE__;
}

sub get_all {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;
    
    my $dataref = $self->storage()->{protocol}->get_all_users();
#    return @users;
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

# FIXME? This does *NOT* allow undef values to be set.
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

# Instance-like interface.
sub property {
    my ($self, $key, $value) = @_;
    
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
    
    return $self->_setter_getter( $key, $value );    
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

    return map { Yggdrasil::Local::Role->get( yggdrasil => $self, role => $_ ) } @r;
}

1;


1;
