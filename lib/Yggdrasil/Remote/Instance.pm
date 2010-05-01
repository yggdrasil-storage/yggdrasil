package Yggdrasil::Remote::Instance;

use strict;
use warnings;

use base qw/Yggdrasil::Instance/;

sub fetch {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    my $dataref = $self->storage()->{protocol}->get_instance( $params{entity}, $params{instance} );
    return unless $dataref;
    $dataref->{yggdrasil} = $self->yggdrasil();
    return bless $dataref, __PACKAGE__;
}

sub property {
    my $self = shift;
    my ($key, $val) = @_;    
    
    if (@_ == 2) {
	return $self->storage()->{protocol}->set_value( $self->{entity}, $key, $self->{id}, $val );
    } else {
	return $self->storage()->{protocol}->get_value( $self->{entity}, $key, $self->{id} );
    }
}

1;
