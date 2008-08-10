package Yggdrasil::MetaProperty;

use strict;
use warnings;

use base qw(Yggdrasil::Meta);

sub _define {
    my $self = shift;

    return $self->{storage}->define( "MetaProperty",
				     fields   => { entity   => { type => "VARCHAR(255)", null => 0 },
						   property => { type => "VARCHAR(255)", null => 0 },
						   id       => { type => "SERIAL" } },
				     temporal => 1,
				     nomap    => 1 );
}

sub _meta_add {
  my $self   = shift;
  my $entity = shift;
  my $key    = shift;

  $self->{storage}->store( "MetaProperty",
			   key    => 'id',
			   fields => {
				      entity   => $entity,
				      property => $key 
				     });
}

1;
