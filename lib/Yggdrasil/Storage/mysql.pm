package Yggdrasil::Storage::mysql;

use strict;
use warnings;

use Carp;

use base 'Yggdrasil::Storage::SQL';

use DBI;

our %TYPEMAP = (
		SERIAL => 'INT AUTO_INCREMENT',
		DATE   => 'DATETIME',		
	       );

sub new {
  my $class = shift;
  my $self  = {};
  my %data  = @_;

  bless $self, $class;

  $self->{dbh} = DBI->connect( "DBI:mysql:database=$data{db};host=$data{host};port=$data{port}", $data{user}, $data{password}, { RaiseError => 0 } );

  return $self;
}

sub _structure_exists {
    my $self = shift;
    my $structure = shift;
    
    my( $e ) = $self->_sql( "SHOW TABLES LIKE '$structure'" );

    for my $row ( @$e ) {
	for my $table ( values %$row ) {
	    return $structure if $table eq $structure;
	}    
    } 
    return 0;
}

sub _map_type {
    my $self = shift;
    my $type = shift;

    return $TYPEMAP{$type} || $type;
}

sub _null_comparison_operator {
    my $self = shift;
    return 'is';
}

__DATA__
sub _get_last_id {
    my $self = shift;

    return $self->{dbh}->{mysql_insertid};
}

1;
