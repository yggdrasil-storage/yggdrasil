package Yggdrasil::Storage::Engine::mysql;

use strict;
use warnings;

use Carp;

use base 'Yggdrasil::Storage::Engine::Shared::SQL';

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

    for my $table ( $self->_list_structures( $structure ) ) {
	return $structure if $table eq $structure;
    }    
    return 0;
}

sub _list_structures {
    my $self = shift;
    my $structure = shift;

    my $string = "SHOW TABLES";
    $string .= " LIKE '%" . $structure . "%'" if $structure;
    
    my( $e ) = $self->_sql( $string );

    my @tables;
    for my $row ( @$e ) {
	for my $table ( values %$row ) {
	    push @tables, $table;
	}
    }
    return @tables;
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

sub _engine_requires_serial_as_key {
    my $self = shift;
    return 1;
}
1;
