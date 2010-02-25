package Yggdrasil::MetaProperty;

use strict;
use warnings;

use base qw(Yggdrasil::Object);

sub define {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my $storage = $self->{yggdrasil}->{storage};
    
    $storage->define( "MetaProperty",
		      fields   => { entity   => { type => "INTEGER",      null => 0 },
				    property => { type => "VARCHAR(255)", null => 0 },
				    type     => { type => "VARCHAR(255)", null => 0 },
				    nullp    => { type => "BOOLEAN",      null => 0 },
				    id       => { type => "SERIAL" } },
		      temporal => 1,
		      nomap    => 1,
		      hints    => { entity => { foreign => 'MetaEntity', index => 1 }, },
		      
		      auth => {
			       # Create a new property.
			       create => { MetaEntity => { entity => '__ENTITY__' },
 					   'MetaEntity:Auth' => { 
								 id     => \qq<MetaEntity.id>,
								 modify => 1,
								},
					 },
			       # Get the property (Entity.ip, not that of an instance).
			       fetch => { MetaProperty => { id => '__SELF__' },
					  ':Auth'        => {
							     id   => \qq<MetaProperty.id>,
							     read => 1, 
							    },
					  
					},
			       # Remove a property from an entity.
			       expire => { MetaEntity => { entity => '__ENTITY__' },
 					   'MetaEntity:Auth' => { 
								 id     => \qq<MetaEntity.id>,
								 modify => 1,
								},
					   MetaProperty => { id => '__SELF__' },
					   ':Auth'        => {
							      id     => \qq<MetaProperty.id>,
							      modify => 1, 
							     },					  
					 },
			       # Change type / possibility of null / rename
			       update => { MetaEntity => { entity => '__ENTITY__' },
 					   'MetaEntity:Auth' => { 
								 id     => \qq<MetaEntity.id>,
								 modify => 1,
								},
					   MetaProperty => { id => '__SELF__' },
					   ':Auth'        => {
							      id     => \qq<MetaProperty.id>,
							      modify => 1, 
							     },					  
					 },
			      },
		    );
}

sub _admin_dump {
    my $self = shift;

    return $self->{storage}->raw_fetch( "MetaProperty" );
}

sub _admin_restore {
    my $self = shift;
    my $data = shift;

    return $self->{storage}->raw_store( "MetaProperty", fields => $data );
}

1;
