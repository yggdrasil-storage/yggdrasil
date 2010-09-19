package Yggdrasil::Remote::Instance;

use strict;
use warnings;

use base qw/Yggdrasil::Instance/;

sub fetch {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    my $e = ref $params{entity}?$params{entity}->_userland_id():$params{entity};
    my $eobj;
    
    if (ref $params{entity}) {
	$e    = $params{entity}->_userland_id();
    } else {
	$e    = $params{entity};
    }

    my $time = $self->_validate_temporal( $params{time} ); 
    return unless $time;    
    
    my @instances = Yggdrasil::Object::objectify( $self->yggdrasil(),
						  __PACKAGE__,
						  $self->storage()->{protocol}->get_instance( $e, $params{instance}, $time ),
						);

    for my $i (@instances) {
	$i->{entity} = Yggdrasil::Remote::Entity->get(
						      yggdrasil => $self->yggdrasil(), 
						      entity    => $e,
						     );
	$i->{visual_id} = $i->{id};
    }
    
    if (wantarray) {
	return @instances;
    } else {
	return $instances[-1];
    }
}

sub get {
    my $self = shift;
    $self->property( @_ );
}

sub set {
    my $self = shift;

    # Do not expire historic objects
    if( $self->stop() ) {
	$self->get_status()->set( 406, "Unable to set values in historic instances" );
	return 0;
    }    

    $self->property( @_ );
}

sub expire {
    my $self  = shift;

    # Do not expire historic objects
    if( $self->stop() ) {
	$self->get_status()->set( 406, "Unable to expire historic instance" );
	return 0;
    }
    
    return $self->storage()->{protocol}->expire_instance( $self->entity()->_userland_id(), $self->_userland_id() );    
}

sub property {
    my $self = shift;
    my ($key, $val) = @_; 

    $key = $key->_userland_id() if ref $key;
    
    if (@_ == 2) {
	return $self->storage()->{protocol}->set_value( $self->entity()->_userland_id(), $key, $self->_userland_id(), $val );
    } else {
	return $self->storage()->{protocol}->get_value( $self->entity()->_userland_id(), $key, $self->_userland_id(),
							{
							 start  => $self->start(),
							 stop   => $self->stop(),
							 format => 'tick',
							}
						      );
    }
}

1;
