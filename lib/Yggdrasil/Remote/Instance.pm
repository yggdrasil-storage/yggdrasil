package Yggdrasil::Remote::Instance;

use strict;
use warnings;

use base qw/Yggdrasil::Instance/;

sub fetch {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    my $e = ref $params{entity}?$params{entity}->_userland_id():$params{entity};

    my $dataref = $self->storage()->{protocol}->get_instance( $e, $params{instance} );
    my $instance = Yggdrasil::Object::objectify( $self->yggdrasil(), __PACKAGE__, $dataref );
    return unless $instance;

    if ($instance->entity()) {
	if (ref $params{entity}) {
	    $instance->{entity} = $params{entity};
	} else {
	    $instance->{entity} = Yggdrasil::Remote::Entity->get( yggdrasil => $self->yggdrasil(), 
								  entity    => $instance->entity() );
	}
	return $instance;
    }
    return;
}

sub get {
    my $self = shift;
    $self->property( @_ );
}

sub set {
    my $self = shift;
    $self->property( @_ );
}

sub expire {
    my $self  = shift;
    return $self->storage()->{protocol}->expire_instance( $self->entity()->_userland_id(), $self->_userland_id() );    
}

sub property {
    my $self = shift;
    my ($key, $val) = @_;    

    $key = $key->_userland_id() if ref $key;
    
    if (@_ == 2) {
	return $self->storage()->{protocol}->set_value( $self->entity()->_userland_id(), $key, $self->_userland_id(), $val );
    } else {
	return $self->storage()->{protocol}->get_value( $self->entity()->_userland_id(), $key, $self->_userland_id() );
    }
}

sub delete :method {
    my $self = shift;
    
    return $self->storage()->{protocol}->expire_instance( $self->entity()->_userland_id(), $self->_userland_id() );
}

1;
