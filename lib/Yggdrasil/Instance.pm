package Yggdrasil::Instance;

use strict;
use warnings;

use Yggdrasil::Local::Instance;
use Yggdrasil::Remote::Instance;

use base qw/Yggdrasil::Object/;

sub create {
    my $class  = shift;
    my %params = @_;
    
    my $yggdrasil = $params{yggdrasil};
    if( $yggdrasil->is_remote() ) {
	return Yggdrasil::Remote::Instance->create( @_ );
    } else {
	return Yggdrasil::Local::Instance->create( @_ );	
    }
}

sub fetch {
    my $class  = shift;
    my %params = @_;
    
    my $yggdrasil = $params{yggdrasil};
    if( $yggdrasil->is_remote() ) {
	return Yggdrasil::Remote::Instance->fetch( @_ );
    } else {
	return Yggdrasil::Local::Instance->fetch( @_ );	
    }
}

sub get_all {
    my $class  = shift;
    my %params = @_;
    
    my $yggdrasil = $params{yggdrasil};
    if( $yggdrasil->is_remote() ) {
	return Yggdrasil::Remote::Instance->get_all( @_ );
    } else {
	return Yggdrasil::Local::Instance->get_all( @_ );	
    }
}

sub id {
    my $self = shift;
    return $self->{visual_id};
}

sub _userland_id {
    my $self = shift;
    return $self->id();
}

sub entity {
    my $self = shift;
    
    return $self->{entity};
}

sub can_write {
    my $self = shift;
    
    return if $self->stop();
    return $self->storage()->can( update => 'Instances', { id => $self->_internal_id() } );
}

sub can_expire {
    my $self = shift;
    
    return if $self->stop();
    return $self->storage()->can( expire => 'Instances', { id => $self->_internal_id() } );
}

sub can_expire_value {
    my $self = shift;
    my $prop = shift;
    
    return if $self->stop();
    return $self->_property_allows( $prop, 'expire' );
}

sub can_write_value {
    my $self = shift;
    my $prop = shift;
    
    return if $self->stop();
    
    # Check to see if the property has any values. If the property
    # exists with a value, we'll get an OK status set, if the property
    # doesn't exist (yet), we'll get something else[tm].
    $self->get( $prop );
    if ($self->get_status()->OK()) {
	return $self->_property_allows( $prop, 'update' );
    } else {
	return $self->_property_allows( $prop, 'create' );
    }
}

sub _property_allows {
    my $self = shift;
    my $prop = shift;
    my $call = shift;

    my $storage = $self->storage();
    my $eobj    = $self->entity();
    my $propobj = ref $prop?$prop:$eobj->get_property( $prop );
    # Don't touch status, leave it as is from the above call.
    return unless $propobj;
    
    my $schema = join(':', $eobj->_userland_id(), $propobj->_userland_id());
    return $storage->can( $call => $schema,
			  { id => $propobj->_internal_id() });
}

1;


