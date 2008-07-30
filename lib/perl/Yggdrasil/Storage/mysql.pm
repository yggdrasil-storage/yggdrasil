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

sub bootstrap_missing {
    my $self = shift;
    my %require = (MetaEntity => 1, MetaInheritance => 1, MetaProperty => 1, MetaRelation => 1);
    
    my $e = $self->dosql_select( "SHOW TABLES LIKE 'Meta%%'" );

    use Data::Dumper;
    print "*", Dumper( $e ), "\n";

    for my $row ( @$e ) {
	for my $table ( values %$row ) {
	    delete $require{$table};
	}    
    } 

    my @missing;
    for my $missing (keys %require) {
	push @missing, $missing;
    }

    return @missing;
}
1;
