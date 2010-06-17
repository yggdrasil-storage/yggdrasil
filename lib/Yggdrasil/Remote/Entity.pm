package Yggdrasil::Remote::Entity;

use strict;
use warnings;

use base qw/Yggdrasil::Entity/;

sub define {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    my $dataref = $self->storage()->{protocol}->define_entity( $params{entity} );
    return Yggdrasil::Object::objectify( $self->yggdrasil(), __PACKAGE__, $dataref );    
}

sub get {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    my $dataref = $self->storage()->{protocol}->get_entity( $params{entity} );
    return Yggdrasil::Object::objectify( $self->yggdrasil(), __PACKAGE__, $dataref );    
}

sub property_exists {
    my $self = shift;

    return $self->get_property( @_ );
}

sub fetch {
    my $self = shift;
    my $instance = shift;
    my %params = @_;

    return Yggdrasil::Remote::Instance->fetch( yggdrasil => $self->yggdrasil(),
					       entity    => $self->_userland_id(),					       
					       instance  => $instance,
					       time      => $params{time},
					     );
}

sub expire {
    my $self = shift;

    return $self->storage()->{protocol}->expire_entity( $self->_userland_id() );
}

sub get_property {
    my $self = shift;
    my $prop = shift;

    return Yggdrasil::Remote::Property->get( yggdrasil => $self->yggdrasil(),
					     entity    => $self,
					     property  => $prop,
					     @_ );
}

sub get_all {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    return Yggdrasil::Object::objectify(
					$self->yggdrasil(),
					__PACKAGE__,
					$self->storage()->{protocol}->get_all_entities(),
				       );
}

sub instances {
    my $self = shift;

    return Yggdrasil::Object::objectify(
					$self->yggdrasil(),
					__PACKAGE__,
					$self->storage()->{protocol}->get_all_instances( $self->_userland_id() ),
				       );
}

sub properties {
    my $self = shift;
    
    my @props = Yggdrasil::Object::objectify(
					     $self->yggdrasil(),
					     'Yggdrasil::Remote::Property',
					     $self->storage()->{protocol}->get_all_properties( $self->_userland_id() ),
					    );
    for my $prop (@props) {
	if ($prop->{entity} eq $self->_userland_id()) {
	    $prop->{entity} = $self;
	} else {
	    $prop->{entity} = $self->yggdrasil()->get_entity( $prop->{entity} );
	}
    }
    return @props;
}

sub create {
    my $self = shift;
    my $id   = shift;
    
    return Yggdrasil::Object::objectify(
					$self->yggdrasil(),
					'Yggdrasil::Remote::Instance',
					$self->storage()->{protocol}->create_instance( $self->_userland_id(), $id ),
				       );
    
}

1;
