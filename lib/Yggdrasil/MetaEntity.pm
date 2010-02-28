package Yggdrasil::MetaEntity;

use strict;
use warnings;

use base qw(Yggdrasil::Object);

sub define {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my $storage = $self->{yggdrasil}->{storage};
    
    # --- Tell Storage to create SCHEMA, noop if it exists.
    $storage->define( "MetaEntity",
		      fields     => {
				     id     => { type => 'SERIAL' },
				     entity => { type => "VARCHAR(255)", null => 0 },
				    },
		      temporal   => 1,
		      nomap      => 1,
		      auth       => {
				     # Create a new entity.  __PARENT__ is expanded to the parent of the
				     # current entity, __AUTH__ expands to "my" auth schema.  Write
				     # access to parent required.
				     create => [
						MetaEntity  => { entity => '__PARENT__' },
						':Auth'     => {
								id    => \qq<MetaEntity.id>,
								w     => 1,
							       },
					       ],
				     # get an entity.  Read self to access.
				     fetch  => [
						MetaEntity  => { entity => '__SELF__' },
						':Auth'     => {
								id   => \qq<MetaEntity.id>,
								r    => 1,
							       },
					       ],
				     # rename entity.  Modify self required.
				     update => [
						MetaEntity  => { entity => '__SELF__' },
						':Auth'       => {								 
								  id     => \qq<MetaEntity.id>,
								  'm'    => 1,
								 },
					       ],
				     # expire / delete entity.  Write to parent, modify self.
				     expire => [
						MetaEntity  => {
								entity => '__SELF__',
								alias  => 'ME1',
							       },
						MetaEntity  => {
								entity => '__PARENT__',
								alias  => 'ME2',
							       },
						':Auth'       => {
								id     => \qq<ME1.id>,
								'm'    => 1,
							       },
						':Auth'       => {
								id     => \qq<ME2.id>,
								w      => 1,
							       },
					       ],
				    },
		    );
    
    $storage->define( "Instances",
		      fields   => { 
				   entity    => { type => "INTEGER" },
				   visual_id => { type => "TEXT" },
				   id        => { type => "SERIAL" } },
		      temporal => 1,
		      nomap    => 1,
		      hints    => {
				   entity => { foreign => 'MetaEntity' },
				  },
		      auth => {
			       # Create instance, require write access to entity.
			       create => [
					  MetaEntity      => { entity => '__ENTITY__' },
					  'MetaEntity:Auth' => {
								id    => \qq<MetaEntity.id>,
								w     => 1,
							       },					  
					 ],
			       # No need to check readability of the entity, as you can
			       # only access the fetch call from that entity object.  If you
			       # have been given that entity object, odds are you can read it.
			       # (Hopefully).
			       fetch  => [
					  Instances => { visual_id => '__SELF__' },
					  ':Auth'     => {
							id   => \qq<Instances.id>,
							r    => 1,
						       },
					 ],
			       # expire / delete instance.
			       expire => [
					  Instances => { visual_id => '__SELF__' },
					  ':Auth'     => {
							id     => \qq<Instances.id>,
							'm'    => 1,
						       },
					  MetaEntity      => { entity => '__ENTITY__' },
					  'MetaEntity:Auth' => {
								id    => \qq<MetaEntity.id>,
								w     => 1,
							       },
					 ],
			       # Rename, edit visual ID.  Modify self, write to entity.
			       update => [
					  Instances => { visual_id => '__SELF__' },
					  ':Auth'     => {
							  id     => \qq<Instances.id>,
							  'm'    => 1,
							 },
					  
					 ],
			      },
		      
		    );
}    

sub add {
    my $class  = shift;
    my $self   = $class->SUPER::new(@_);
    my %params = @_;

    my $name = $params{entity};
    
    $self->{yggdrasil}->{storage}->store( "MetaEntity", key => "entity", fields => { entity => $name } );

    unless ($self->{yggdrasil}->{bootstrap}) {
	# FIX: should we have a ->get_authenticated_user() ?
	my $user = $self->yggdrasil()->user();
	for my $role ( $user->get_cached_member_of() ) {
	    $role->grant( $name, 'd' );
	}
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
