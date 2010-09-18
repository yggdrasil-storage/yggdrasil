package Yggdrasil::Entity;

use strict;
use warnings;

use Yggdrasil::Local::Entity;
use Yggdrasil::Remote::Entity;

use base qw/Yggdrasil::Object/;

sub define {
    my $class = shift;
    my %params = @_;

    my $yggdrasil = $params{yggdrasil};
    if( $yggdrasil->is_remote() ) {
	return Yggdrasil::Remote::Entity->define( @_ );
    } else {
	return Yggdrasil::Local::Entity->define( @_ );
    }
}

sub get {
    my $class = shift;
    my %params = @_;

    my $yggdrasil = $params{yggdrasil};
    if( $yggdrasil->is_remote() ) {
	return Yggdrasil::Remote::Entity->get( @_ );
    } else {
	return Yggdrasil::Local::Entity->get( @_ );
    }
}

sub expire {
    my $class = shift;
    my %params = @_;

    my $yggdrasil = $params{yggdrasil};
    my $entity;
    if( $yggdrasil->is_remote() ) {
	$entity = Yggdrasil::Remote::Entity->get( @_ );
    } else {
	$entity = Yggdrasil::Local::Entity->get( @_ );
    }
    return unless $yggdrasil->get_status()->OK();
    return $entity->expire();
}

sub get_all {
    my $class = shift;
    my %params = @_;

    my $yggdrasil = $params{yggdrasil};
    if( $yggdrasil->is_remote() ) {
	return Yggdrasil::Remote::Entity->get_all( @_ );
    } else {
	return Yggdrasil::Local::Entity->get_all( @_ );
    }
}

sub instances {
    my $class = shift;
    my %params = @_;
    my $yggdrasil = $params{yggdrasil};
    my $entity = $yggdrasil->get_entity( $params{entity} );
    
    return unless $yggdrasil->get_status()->OK();
    return $entity->instances( @_ );
}

sub relations {
    my $class = shift;
    my %params = @_;
    my $yggdrasil = $params{yggdrasil};
    my $entity = $yggdrasil->get_entity( $params{entity} );
    
    return unless $yggdrasil->get_status()->OK();
    return $entity->relations( @_ );
}

sub properties {
    my $class = shift;
    my %params = @_;

    my $yggdrasil = $params{yggdrasil};
    my $entity = $yggdrasil->get_entity( $params{entity} );
    
    return unless $yggdrasil->get_status()->OK();
    return sort { $a->name() <=> $b->name() } $entity->properties( @_ );
}

sub id {
    my $self = shift;
    return $self->{name};
}

sub parent {
    my $self = shift;

    return unless $self->{parent};

    if( $self->yggdrasil()->is_remote() ) {
	return Yggdrasil::Remote::Entity->get( entity => $self->{parent}, yggdrasil => $self->yggdrasil() );
    } else {
	return Yggdrasil::Local::Entity->get( id => $self->{parent}, yggdrasil => $self->yggdrasil() );
    }
}

sub _userland_id {
    my $self = shift;
    return $self->id();
}

sub can_write {
    my $self = shift;
    
    return if $self->stop();
    return $self->storage()->can( update => 'MetaEntity', { id => $self->_internal_id() } );
}

sub can_expire {
    my $self = shift;
    
    return if $self->stop();
    return $self->storage()->can( expire => 'MetaEntity', { id => $self->_internal_id() } );
}

sub can_instanciate {
    my $self = shift;

    return $self->storage()->can( create => 'Instances', { entity => $self->_internal_id() } );
}

sub can_create_subentity {
    my $self = shift;

    return $self->storage()->can( create => 'MetaEntity', { parent => $self->_internal_id() } );
}


1;
