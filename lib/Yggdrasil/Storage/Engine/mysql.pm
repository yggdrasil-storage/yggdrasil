package Yggdrasil::Storage::Engine::mysql;

use strict;
use warnings;

use base 'Yggdrasil::Storage::Engine::Shared::SQL';

use DBI;

use Yggdrasil::Status;

our %TYPEMAP = (
		DATE     => 'DATETIME',
		BINARY   => 'MEDIUMBLOB', # 2^24, 16MiB.
                PASSWORD => 'VARCHAR(255)',
	       );

sub new {
  my $class = shift;
  my $self  = {};
  my %data  = @_;

  bless $self, $class;

  my $status = new Yggdrasil::Status;

  my @missing;
  for my $param (qw|host user password db|) {
      push @missing, $param unless $data{$param};
  }

  if (@missing) {
      $status->set( 404, 'Missing database parameter(s): ' . join ", ", @missing );
      return undef;
  }

  $data{port} ||= 3306;
  
  $self->{dbh} = DBI->connect( "DBI:mysql:database=$data{db};host=$data{host};port=$data{port}", $data{user}, $data{password}, { RaiseError => 1 } );

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

sub _fields_in_structure {
    my $self = shift;
    my $structure = shift;

    my ( $e ) = $self->_sql("SHOW FIELDS FROM $structure");

    return map { $_->{Field} } @$e;
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

sub _convert_time {
    my $self = shift;
    my $time = shift;

    return $time unless defined $time;

    if( $self->_isepoch($time) ) {
	return "FROM_UNIXTIME($time)";
    }
    return $time;
}

sub _time_as_epoch {
    my $self = shift;
    my $time = shift;

    return "UNIX_TIMESTAMP($time)";
}

1;
