package Yggdrasil::Entity;

use strict;
use warnings;

use base qw(Yggdrasil::MetaEntity);

use Yggdrasil::Entity::Instance;
  
sub _define {
    my $self = shift;
    my $name = shift;

    my $package = join '::', $self->{namespace}, $name;
    unless ($self->{storage}->exists( $name )) {
	# --- Tell Storage to create SCHEMA    
	$self->{storage}->define( $name,
				  fields   => { visual_id => { type => "TEXT" },
						id        => { type => "SERIAL" } },
				  temporal => 0 );

	# --- Add to MetaEntity;
	$self->_meta_add($name);

	# --- Create namespace
	$self->_register_namespace( $package );
	
	# --- Create property to store visual_id changes
	define $package "_$name";
    }
    
    return $package;
}

1;
