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
    } else {
	# Unknown stuff.
	return undef;
    }
}

sub _create_entity {
    my $self = shift;
    my $data = shift;
    delete $data->{entity};
    
    print "Entity:\n";
    for my $k (keys %$data) {
	printf "%20s - %s\n", $k, $data->{$k};
    }
}

sub _create_property {
    my $self = shift;
    my $data = shift;
    delete $data->{property};

    print "Property:\n";
    for my $k (keys %$data) {
	printf "%20s - %s\n", $k, $data->{$k};
    }
}

sub _create_relation {
    my $self = shift;
    my $data = shift;
    delete $data->{relation};

    print "Relation:\n";
    for my $k (keys %$data) {
	printf "%20s - %s\n", $k, $data->{$k};
    }
}

sub _create_instance {
    my $self = shift;
    my $data = shift;
    delete $data->{instance};

    print "Instance:\n";
    for my $k (keys %$data) {
	printf "%20s - %s\n", $k, $data->{$k};
    }
}

sub _create_value {
    my $self = shift;
    my $data = shift;

    print "Value:\n";
    for my $k (keys %$data) {
	printf "%20s - %s\n", $k, $data->{$k};
    }
}

1;
