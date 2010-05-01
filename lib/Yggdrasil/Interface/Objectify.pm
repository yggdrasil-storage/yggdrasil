package Yggdrasil::Interface::Objectify;

use warnings;
use strict;

sub new {
    my $class = shift;
    my $self = bless {}, $class;

    return $self;
};

sub parse {
    my $self = shift;
    my $data = shift;

    if ($data->{value}) {
	$self->_create_value( $data );
    } elsif ($data->{instance}) {
	$self->_create_instance( $data );
    } elsif ($data->{property}) {
	$self->_create_property( $data );	
    } elsif ($data->{relation}) {
	$self->_create_relation( $data );
    } elsif ($data->{entity}) {
	$self->_create_entity( $data );
    } elsif ($data->{user}) {
	$self->_create_user( $data );
    } elsif ($data->{role}) {
	$self->_create_role( $data );
    } else {
	# Unknown stuff.
	return undef;
    }
}

sub _create_entity {
    my $self = shift;
    my $data = shift;
    delete $data->{entity};
    return $data;
}

sub _create_property {
    my $self = shift;
    my $data = shift;
    delete $data->{property};
    return $data;
}

sub _create_relation {
    my $self = shift;
    my $data = shift;
    delete $data->{relation};
    return $data;
}

sub _create_instance {
    my $self = shift;
    my $data = shift;
    delete $data->{instance};
    return $data;
}

sub _create_value {
    my $self = shift;
    my $data = shift;
    return $data->{value};
}

sub _create_user {
    my $self = shift;
    my $data = shift;
    delete $data->{user};
    return $data;
}

sub _create_role {
    my $self = shift;
    my $data = shift;
    delete $data->{role};
    return $data;
}

1;
