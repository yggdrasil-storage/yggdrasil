package Yggdrasil::Storage::Pg;

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

  print "Connecting\n";
  
  $self->{dbh} = DBI->connect( "DBI:Pg:database=$data{db};host=$data{host};port=$data{port}", $data{user}, $data{password}, { RaiseError => 0 } );

  print "Connected\n";
  
  return $self;
}

sub meta_exists {
    my $self = shift;
    my $meta = shift;
    
    my $e = $self->dosql_select( "SELECT table_name FROM information_schema.tables WHERE table_schema = 'public'" );

    print "* $e";
    
    for my $row ( @$e ) {
	print " - $row\n";;
	for my $table ( values %$row ) {
	    print "  | $table\n";
	    return $meta if lc $table eq lc $meta;
	}    
    } 
    return 0;
}

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
