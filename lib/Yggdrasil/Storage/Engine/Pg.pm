package Yggdrasil::Storage::Engine::Pg;

use strict;
use warnings;

use Carp;

use base 'Yggdrasil::Storage::Engine::Shared::SQL';

use DBI;

our %TYPEMAP = (
		DATE   => 'TIMESTAMP WITH TIME ZONE',
		BINARY => 'BYTEA',
	       );
  
sub new {
  my $class = shift;
  my $self  = {};
  my %data  = @_;

  bless $self, $class;
  
  $self->{dbh} = DBI->connect( "DBI:Pg:database=$data{db};host=$data{host};port=$data{port}", $data{user}, $data{password}, { RaiseError => 0 } );

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

1;
