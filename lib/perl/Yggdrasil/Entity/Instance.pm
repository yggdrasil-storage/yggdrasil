package Yggdrasil::Entity::Instance;

use base 'Yggdrasil';

use strict;
use warnings;

sub new {
  my $class = shift;
  my %data  = @_;
  my $self  = \%data;
  
  bless $self, $class;

  return $self;
}

sub define {
    
}

sub property {
    my $self = shift;
    my ($key, $value) = @_;

    my $storage = $self->storage();

    my $entity = (split '::', ref $self)[-1];    
    my $name = join("_", $entity, $key );
      
    if ($value) {

	my $id = $storage->dosql_update(
qq<INSERT INTO [name] (id, value, start) VALUES(?, ?, NOW())>, 
 $self, [$entity->{id}, $value] );
    
}
					
	return $storage->
    }
    
}

1;
