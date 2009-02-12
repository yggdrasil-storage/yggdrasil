package Yggdrasil::Storage::Engine::Pg;

use strict;
use warnings;

use base 'Yggdrasil::Storage::Engine::Shared::SQL';

use DBI;

our %TYPEMAP = (
		DATE     => 'TIMESTAMP WITH TIME ZONE',
		BINARY   => 'BYTEA',
                PASSWORD => 'VARCHAR(255)',
	       );

sub new {
  my $class = shift;
  my $self  = {};
  my %data  = @_;

  bless $self, $class;
  
  $self->{dbh} = DBI->connect( "DBI:Pg:database=$data{db};host=$data{host};port=$data{port}", $data{user}, $data{password}, { RaiseError => 1 } );

  $self->{dbh}->{Warn} = 0;

  return $self;
}

sub _structure_exists {
    my $self = shift;
    my $structure = shift;

    for my $table ( $self->_list_structures() ) {
	return $structure if lc $table eq lc $structure;
    }    
    return 0;
}

sub _list_structures {
    my $self = shift;
    my $structure = shift;

    # And table name LIKE?  Fix this.
    my $string = "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'";
    
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
    my $structure = lc shift;

    my ( $e ) = $self->_sql("SELECT a.attnum, a.attname AS field, t.typname AS type,
       a.attlen AS length, a.atttypmod AS length_var,
       a.attnotnull AS not_null, a.atthasdef as has_default
  FROM pg_class c, pg_attribute a, pg_type t
 WHERE c.relname = '$structure'
AND a.attnum > 0
   AND a.attrelid = c.oid
   AND a.atttypid = t.oid
 ORDER BY a.attnum");
    
    return map { $_->{field} } @$e;
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

sub _time_as_epoch {
    my $self = shift;
    my $time = shift;

    return "(floor(extract(epoch FROM ($time)::timestamp with time zone)))";
}

sub _convert_time {
     my $self = shift;
     my $time = shift;

     return unless $time;
 
     return "${time}::abstime::timestamp with time zone";
}
1;
