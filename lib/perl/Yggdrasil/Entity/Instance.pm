package Yggdrasil::Entity::Instance;

use strict;
use warnings;

use Yggdrasil::Storage;

sub new {
  my $class = shift;
  my %data  = @_;
  my $self  = \%data;
  
  bless $self, $class;

  return $self;
}

sub property {
  my $self = shift;
  my %data = @_;

  my $entity = $self->{entity}->{name};
  my $table = join("_", $entity, $data{key});

  my $id = $self->{id};

  my $storage = Yggdrasil::Storage->new();
  $storage->dosql_update( qq<INSERT INTO [name] (id, value, start) VALUES(?, ?, NOW())>, name => $table, [$id, $data{value}] );
}

1;
