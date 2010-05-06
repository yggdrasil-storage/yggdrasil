package Yggdrasil::Remote::Instance;

use strict;
use warnings;

use base qw/Yggdrasil::Instance/;

sub fetch {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    my $dataref = $self->storage()->{protocol}->get_instance( $params{entity}, $params{instance} );
    return Yggdrasil::Object::objectify( $self->yggdrasil(), __PACKAGE__, $dataref );
}

sub get {
    my $self = shift;
    $self->property( @_ );
}

sub set {
    my $self = shift;
    $self->property( @_ );
}

sub property {
    my $self = shift;
    my ($key, $val) = @_;    

    $key = $key->{id} if ref $key;
    
    if (@_ == 2) {
	return $self->storage()->{protocol}->set_value( $self->{entity}, $key, $self->{id}, $val );
    } else {
	return $self->storage()->{protocol}->get_value( $self->{entity}, $key, $self->{id} );
    }
}

sub name {
    my $self = shift;
    return $self->{name};
}

sub id {
    my $self = shift;
    return $self->name();
}

1;
