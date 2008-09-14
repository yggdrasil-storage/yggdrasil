package Yggdrasil::Entity;

use strict;
use warnings;

use base qw(Yggdrasil::MetaEntity);

use Yggdrasil::Entity::Instance;
  
sub _define {
    my $self  = shift;
    my $name  = shift;

    my %param = @_;
    
    my $package = join '::', $self->{namespace}, $name;

    # --- Tell Storage to create SCHEMA, noop if it exists.
    $self->{storage}->define( $name,
			      fields   => { visual_id => { type => "TEXT" },
					    id        => { type => "SERIAL" } },
			      temporal => 0 );
    
    # --- Add to MetaEntity, noop if it exists.
    $self->_meta_add($name) unless $param{raw};
    
    # --- Create namespace, redefined if it exists.
    $self->_register_namespace( $package );
    
    return $package;
}

sub _admin_dump {
    my $self   = shift;
    my $entity = shift;

    return $self->{storage}->raw_fetch( $entity );
}

sub _admin_restore {
    my $self   = shift;
    my $entity = shift;
    my $ids    = shift;

    my %map;
    for( my $i=1; $i<@$ids; $i+=2 ) {
	my $id = $ids->[$i];
	$self->{storage}->raw_store( $entity, fields => { visual_id => $id } );

	my $idfetch = $self->{storage}->fetch( $entity =>
					       { return => "id", 
						 where => { visual_id => $id } } );
	my $idnum = $idfetch->[0]->{id};

	$map{$id} = $idnum;
    }

    return \%map;
}

sub _admin_define {
    my $self = shift;
    my $schema = shift;

    $self->_define( $schema, raw => 1 );
}

1;
