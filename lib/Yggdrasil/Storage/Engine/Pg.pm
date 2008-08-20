package Yggdrasil::Storage::Engine::Pg;

use strict;
use warnings;

use Carp;

use base 'Yggdrasil::Storage::Engine::Shared::SQL';

use DBI;

our %TYPEMAP = (
		DATE   => 'TIMESTAMP',
		BINARY => 'BYTEA',
	       );

our %FUNCTIONS = (
		  "from_unixtime:1" => "
CREATE OR REPLACE FUNCTION from_unixtime(integer) RETURNS timestamp AS '
SELECT
\$1::abstime::timestamp without time zone AS result
' LANGUAGE 'SQL';",
		  
		  "unix_timestamp:0"   => "
CREATE OR REPLACE FUNCTION unix_timestamp() RETURNS integer AS '
SELECT
ROUND(EXTRACT( EPOCH FROM abstime(now()) ))::int4 AS result;
' LANGUAGE 'SQL';",
		  
		  "unix_timestamp:1" => "		  
CREATE OR REPLACE FUNCTION unix_timestamp(timestamp with time zone) RETURNS integer AS '
SELECT
ROUND(EXTRACT( EPOCH FROM ABSTIME(\$1) ))::int4 AS result;
' LANGUAGE 'SQL';"
);
  
sub new {
  my $class = shift;
  my $self  = {};
  my %data  = @_;

  bless $self, $class;
  
  $self->{dbh} = DBI->connect( "DBI:Pg:database=$data{db};host=$data{host};port=$data{port}", $data{user}, $data{password}, { RaiseError => 0 } );

  $self->_init();

  return $self;
}

sub _init {
    my $self = shift;

    my $dbh = $self->{dbh};
    my $sth = $dbh->prepare( "select proname,pronargs from pg_proc where proname LIKE '%unix%'" );
    confess( "no sth? " . $dbh->errstr ) unless $sth;
    $sth->execute() || confess( "execute??" );

    my $data = $sth->fetchall_arrayref();
    my %proc_exists;
    
    for my $proc (@$data) {
	my ($name, $args) = ($proc->[0], $proc->[1] || 0);
	$proc_exists{"$name:$args"} = 1;
    } 
    
    for my $proc (qw|unix_timestamp:0 unix_timestamp:1 from_unixtime:1|) {
	unless ($proc_exists{$proc}) {
	    $dbh->do( $FUNCTIONS{$proc} );
	}
    }   
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
