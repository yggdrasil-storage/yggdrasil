package Yggdrasil::Storage::mysql;

use strict;
use warnings;

use Carp;

use DBI;

sub new {
  my $class = shift;
  my $self  = {};
  my %data  = @_;

  bless $self, $class;

  $self->{dbh} = DBI->connect( "DBI:mysql:database=$data{db};host=$data{host};port=$data{port}", $data{user}, $data{password}, { RaiseError => 0 } );

  return $self;
}

sub _prepare_sql {
  my $self = shift;
  my $sql  = shift;
  my $data = shift;

  $sql =~ s/\[(.+?)\]/$data->{$1}/ge;
  return $sql;
}

sub dosql_select {
  my $self = shift;
  my $sql  = shift;
  
  my $args;
  $args = pop if ref $_[-1] eq "ARRAY";
  
  $sql = $self->_prepare_sql( $sql, @_ );

  my $sth = $self->{dbh}->prepare( $sql );
  confess( "no sth?" ) unless $sth;

  $sth->execute(@$args) 
    || confess( "execute??" );

  # foo
}

sub dosql_update {
  my $self = shift;
  my $sql  = shift;

  my $args;
  $args = pop if ref $_[-1] eq "ARRAY";
  
  $sql = $self->_prepare_sql( $sql, @_ );

  my $sth = $self->{dbh}->prepare( $sql );
  confess( "failed to prepare '$sql'") unless $sth;

  my $args_str = join(", ", map { defined()?$_:"NULL" } @$args);

  $sth->execute(@$args) 
    || confess( "failed to execute '$sql' with arguments [$args_str]" );

  return $self->{dbh}->{mysql_insertid};
}


1;
