package Yggdrasil::Storage::Engine::Pg;

use strict;
use warnings;

use Carp;

use base 'Yggdrasil::Storage::Engine::Shared::SQL';

use DBI;

our %TYPEMAP = (
		DATE   => 'TIMESTAMP',		
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

1;

__DATA__

sub _get_last_id {
    my $self = shift;
    my $schema = shift;
    my $table = shift;
    
    if ($schema =~ /insert into (\w+)\(/i) {
        $table = $1;
    }
    
    return $self->{dbh}->last_insert_id( undef, undef, lc $table, undef );
}

sub _table_filter {
    my $self = shift;
    my $sql  = shift;

    $sql =~ s/DATETIME/TIMESTAMP/g;
    $sql =~ s/INT NOT NULL AUTO_INCREMENT/BIGSERIAL/g;
    $sql =~ s/(\w+)\(\d+\)/$1/g;
    
    return $sql;
}

# This exists to fix case issues in Postgresql, ie, the
# 'relation "MyTable" does not exist' annoyances
sub _update_filter {
    my $self = shift;
    my $sql  = shift;

    $sql =~ s/^UPDATE (\w+)//;
    my $table = $1;
    $sql = "UPDATE " . lc $table . " $sql";
    return $sql;
}

1;
