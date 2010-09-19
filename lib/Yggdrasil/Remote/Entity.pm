package Yggdrasil::Remote::Entity;

use strict;
use warnings;

use base qw/Yggdrasil::Entity/;

sub define {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    my $ename = $params{entity};
    if ($params{parent}) {
	$ename = join "::", $params{parent}, $params{entity};
    }
    
    my $dataref = $self->storage()->{protocol}->define_entity( $ename );
    return Yggdrasil::Object::objectify( $self->yggdrasil(), __PACKAGE__, $dataref );
}

sub get {
    my $class = shift;

    if (ref $class) {
	# You ment to call fetch, didn't you?  Yes, you did.
	return $class->fetch( @_ );
    }
    
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    my $time = $self->_validate_temporal( $params{time} );
    return unless $time;    
    
    my $dataref = $self->storage()->{protocol}->get_entity( $params{entity}, $time );
    return Yggdrasil::Object::objectify( $self->yggdrasil(), __PACKAGE__, $dataref );    
}

sub property_exists {
    my $self = shift;
    
    return $self->get_property( @_ );
}

sub descendants {
    my $self = shift;
    my %params = @_;

    my $time = $self->_validate_temporal( $params{time} ); 
    return unless $time;    

    return $self->storage()->{protocol}->get_entity_descendants( $self->_userland_id(), $time );
}

sub ancestors {
    my $self = shift;
    my %params = @_;
    my $time = $self->_validate_temporal( $params{time} ); 
    return unless $time;    
    return $self->storage()->{protocol}->get_entity_ancestors( $self->_userland_id(), $time );
}

sub children {
    my $self = shift;
    my %params = @_;
    my $time = $self->_validate_temporal( $params{time} ); 
    return unless $time;    
    return Yggdrasil::Object::objectify( $self->yggdrasil(),
					 __PACKAGE__,
					 $self->storage()->{protocol}->get_entity_children( $self->_userland_id(), $time ));
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

    # Do not expire historic Entities
    if( $self->stop() ) {
	$self->get_status()->set( 406, "Unable to expire historic entity" );
	return 0;
    }

    # Do not expire UNIVERSAL.  That's bad.
    if ($self->_internal_id() == 1) {
	$self->get_status()->set( 403, "Unable to expire the root entity, 'UNIVERSAL'");
	return 0;
    }
    
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

    my $time = $self->_validate_temporal( $params{time} ); 
    return unless $time;
    
    return Yggdrasil::Object::objectify(
					$self->yggdrasil(),
					__PACKAGE__,
					$self->storage()->{protocol}->get_all_entities( $time ),
				       );
}

sub instances {
    my $self = shift;
    my %params = @_;

    my $time = $self->_validate_temporal( $params{time} ); 
    return unless $time;

    return map { $_->{visual_id} = $_->{id}; $_ }
      Yggdrasil::Object::objectify(
				   $self->yggdrasil(),
				   'Yggdrasil::Remote::Instance',
				   $self->storage()->{protocol}->get_all_instances( $self->_userland_id(), $time ),
				  );
}

sub relations {
    my $self = shift;
    my %params = @_;

    my $time = $self->_validate_temporal( $params{time} ); 
    return unless $time;
    
    my @objs = Yggdrasil::Object::objectify(
					    $self->yggdrasil(),
					    'Yggdrasil::Remote::Relation',
					    $self->storage()->{protocol}->get_all_entity_relations( $self->_userland_id(), $time ),
					   );

    for my $o (@objs) {
	$o->{lval} = $self->yggdrasil()->get_entity( $o->{lval} );
	$o->{rval} = $self->yggdrasil()->get_entity( $o->{rval} );
    }
    return @objs;
}

sub properties {
    my $self = shift;
    my %params = @_;

    my $time = $self->_validate_temporal( $params{time} ); 
    return unless $time;    

    my @props = Yggdrasil::Object::objectify(
					     $self->yggdrasil(),
					     'Yggdrasil::Remote::Property',
					     $self->storage()->{protocol}->get_all_properties( $self->_userland_id(), $time ),
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

    # Do not create instances in historic context.
    if( $self->stop() ) {
	$self->get_status()->set( 406, "Unable to create instances in historic context" );
	return 0;
    }
    
    return Yggdrasil::Object::objectify(
					$self->yggdrasil(),
					'Yggdrasil::Remote::Instance',
					$self->storage()->{protocol}->create_instance( $self->_userland_id(), $id ),
				       );
    
}

1;
