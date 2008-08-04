package Yggdrasil::Storage::mysql;

use strict;
use warnings;

use Carp;

use base 'Yggdrasil::Storage::SQL';

use DBI;

sub new {
  my $class = shift;
  my $self  = {};
  my %data  = @_;

  bless $self, $class;

  $self->{dbh} = DBI->connect( "DBI:mysql:database=$data{db};host=$data{host};port=$data{port}", $data{user}, $data{password}, { RaiseError => 0 } );

  return $self;
}

sub meta_exists {
    my $self = shift;
    my $meta = shift;
    
    my $e = $self->dosql_select( "SHOW TABLES LIKE '$meta'" );

    for my $row ( @$e ) {
	for my $table ( values %$row ) {
	    return $meta if $table eq $meta;
	}    
    } 
    return 0;

}

sub _get_last_id {
    my $self = shift;

    return $self->{dbh}->{mysql_insertid};
}

1;
