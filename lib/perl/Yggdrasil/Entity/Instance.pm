package Yggdrasil::Entity::Instance;

use strict;
use warnings;

sub new {
  my $class = shift;
  my %data  = @_;
  my $self  = \%data;
  
  bless $self, $class;

  return $self;
}

1;
