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
				     parent => { type => 'INTEGER', null => 1 },
				     entity => { type => "VARCHAR(255)", null => 0 },
				    },
		      temporal   => 1,
		      nomap      => 1,
		      hints      => {
				     parent => { foreign => 'MetaEntity' },
				     entity => { index => 1 },
				    },
		      authschema => 1,
		      auth       => {
				     # get an entity.  Read self to access.
				     fetch  => [
						':Auth' => {
							    where => [
								      id   => \qq<MetaEntity.id>,
								      r    => 1,
								     ],
							   },
					       ],
				     # rename entity.  Modify self required.
				     update => [
						':Auth' => { 
							    where => [
								      id     => \qq<MetaEntity.id>,
								      'm'    => 1,
								     ],
							   },
					       ],
				     # expire / delete entity.  Write to parent, modify self.
				     expire => [
						':Auth' => {
							    where => [
								      id => \qq<MetaEntity.parent>,
								      w  => 1,
								     ],
							   },
						':Auth' => {
							    where => [
								      id  => \qq<MetaEntity.id>,
								      'm' => 1,
								     ],
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
				   entity => { foreign => 'MetaEntity', index => 1 },
				  },
		      authschema => 1,
		      auth => {
			       # Create instance, require write access to entity.
			       create => [
					  'MetaEntity:Auth' => { 
								where => [
									  id    => \qq<entity>,
									  w     => 1,
									 ],
							       },
					 ],
			       # No need to check readability of the entity, as you can
			       # only access the fetch call from that entity object.  If you
			       # have been given that entity object, odds are you can read it.
			       # (Hopefully).
			       fetch  => [
					  ':Auth' => {
						      where => [
								id   => \qq<Instances.id>,
								r    => 1,
							       ],
						     },
					 ],
			       # expire / delete instance.
			       expire => [
					  ':Auth' => { 
						      where => [
								id     => \qq<Instances.id>,
								'm'    => 1,
							       ],
						     },
					  'MetaEntity:Auth' => {
								where => [
									  id    => \qq<Instances.entity>,
									  w     => 1,
									 ],
							       },
					 ],
			       # Rename, edit visual ID.  Modify self, write to entity.
			       update => [
					  ':Auth' => {
						      where => [
								id     => \qq<Instances.id>,
								'm'    => 1,
							       ],
						     },
					 ],
			      },
		      
		    );
}    

sub define_create_auth {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my $storage = $self->{yggdrasil}->{storage};
    $storage->set_auth( MetaEntity =>
			# Write access to parent required.
			create => [
				   ':Auth' => {
					       where => [
							 id    => \qq<parent>,
							 w     => 1,
							],
					      },
				  ],
		      );
}

sub add {
    my $class  = shift;
    my $self   = $class->SUPER::new(@_);
    my %params = @_;

    my $fields = { entity => $params{entity} };
    $fields->{parent} = $params{parent} if exists $params{parent};

    my $id = $self->{yggdrasil}->{storage}->store( "MetaEntity", key => [qw/entity parent/],
						   fields => $fields );
}

1;
