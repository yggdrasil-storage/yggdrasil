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
		      authschema => 1,
		      auth => {
			       # Create a new property.
			       create => [
					  'MetaEntity:Auth' => {
								where => [
									  id  => \qq<entity>,
									  'm' => 1,
									 ],
							       },
					 ],
			       # Get the property (Entity.ip, not that of an instance).
			       fetch => [ 
					 ':Auth' => {
						     where => [
							       id => \qq<MetaProperty.id>,
							       r  => 1, 
							      ],
						    },
					  
					],
			       # Remove a property from an entity.
			       expire => [ 
					  'MetaEntity:Auth' => { 
								where => [
									  id  => \qq<MetaProperty.entity>,
									  'm' => 1,
									 ],
							       },
					  ':Auth' => {
						      where => [
								id  => \qq<MetaProperty.id>,
								'm' => 1, 
							       ],
						     },
					 ],
			       # Change type / possibility of null / rename
			       update => [ 
					  'MetaEntity:Auth' => { 
								where => [
									  id  => \qq<MetaProperty.entity>,
									  'm' => 1,
									 ],
							       },
					  ':Auth' => {
						      where => [
								id  => \qq<MetaProperty.id>,
								'm' => 1, 
							       ],
						     },
					 ],
			      },
		    );
}

1;
