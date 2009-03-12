package Yggdrasil::MetaEntity;

use strict;
use warnings;

use base qw(Yggdrasil::Meta);

sub _define {
    my $self = shift;
    my $storage = $self->{yggdrasil}->{storage};
    
    # --- Tell Storage to create SCHEMA, noop if it exists.
    $storage->define( "MetaEntity",
		      fields   => {
				   id     => { type => 'SERIAL' },
			       entity => { type => "VARCHAR(255)", null => 0 },
				  },
		      temporal => 1,
		      nomap    => 1, );
    
    $storage->define( "Entities",
		      fields   => { 
				   entity    => { type => "INTEGER" },
				   visual_id => { type => "TEXT" },
				   id        => { type => "SERIAL" } },
		      temporal => 1,
		      nomap    => 1,
		      hints    => {
				   entity => { foreign => 'MetaEntity' },
				  }			      


		    );
}    

sub _meta_add {
    my $self = shift;
    my $name = shift;
    
    $self->{yggdrasil}->{storage}->store( "MetaEntity", key => "entity", fields => { entity => $name } );

    unless ($self->{yggdrasil}->{bootstrap}) {
	my $role = $self->{yggdrasil}->get_role_from_active_user();
	$role->grant( $name, 'd' );
    }
}

sub _admin_dump {
    my $self = shift;

    return $self->{storage}->raw_fetch( "MetaEntity" );
}

sub _admin_restore {
    my $self = shift;
    my $data = shift;

    $self->{storage}->raw_store( "MetaEntity", fields => $data );

    my $id = $self->{storage}->raw_fetch( MetaEntity => 
					  { return => "id",
					    where  => [ %$data ] } );

    return $id->[0]->{id};
}

1;
