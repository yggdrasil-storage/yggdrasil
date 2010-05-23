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

sub properties {
    my $class = shift;
    my %params = @_;

    my $yggdrasil = $params{yggdrasil};
    my $entity = $yggdrasil->get_entity( $params{entity} );
    
    return unless $yggdrasil->get_status()->OK();
    return sort { $a->name() <=> $b->name() } $entity->properties( @_ );
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
