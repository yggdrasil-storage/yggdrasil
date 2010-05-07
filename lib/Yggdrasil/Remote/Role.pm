package Yggdrasil::Remote::Role;

use strict;
use warnings;

use base qw/Yggdrasil::Role/;

sub get {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    my %params = @_;

    return Yggdrasil::Object::objectify(
					$self->yggdrasil(),
					__PACKAGE__,
					$self->storage()->{protocol}->get_role( $params{role} ),
				       );
}

sub get_all {
    my $class = shift;
    my $self  = $class->SUPER::new( @_ );
    my %params = @_;

    return Yggdrasil::Object::objectify(
					$self->yggdrasil(),
					__PACKAGE__,
					$self->storage()->{protocol}->get_all_roles(),
				       );
}

sub _setter_getter {
    my $self = shift;
    my $key  = shift;

    if( @_ ) {
	print "CALLING SET? (@_), ", scalar @_, "\n";
	$self->storage()->{protocol}->set_role_value( $self->id(), $key, $_[0] );
	return $_[0];
    }

    return $self->storage()->{protocol}->get_role_value( $self->id(), $key );
}

sub rolename {
    my $self = shift;
    return $self->id();
}

sub id {
    my $self = shift;
    return $self->{name};
}

sub description {
    my $self = shift;
    return $self->_setter_getter( description => @_ );
}

sub members {
    my $self = shift;
    my @r = $self->storage()->{protocol}->get_members( $self->id() );
    return Yggdrasil::Object::objectify(
					$self->yggdrasil(),
					'Yggdrasil::Remote::User',
					@r
					);
}

1;
