package Yggdrasil::Entity;

use strict;
use warnings;

use base qw(Yggdrasil::MetaEntity);

use Yggdrasil::Entity::Instance;
  
sub _define {
    my $self = shift;
    my $name = shift;

    my $package = join '::', $self->{namespace}, $name;

    # --- Tell Storage to create SCHEMA, noop if it exists.
    $self->{storage}->define( $name,
			      fields   => { visual_id => { type => "TEXT" },
					    id        => { type => "SERIAL" } },
			      temporal => 0 );
    
    # --- Add to MetaEntity, noop if it exists.
    $self->_meta_add($name);
    
    # --- Create namespace, redefined if it exists.
    $self->_register_namespace( $package );
    
    return $package;
}

1;
