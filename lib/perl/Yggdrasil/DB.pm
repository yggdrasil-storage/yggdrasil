package Yggdrasil::DB;

use strict;
use warnings;

our $dbh;

sub new {
  my $class = shift;
  my $self  = {};
  my %data = @_;

  return $dbh if $dbh;

  my $engine = join(".", $data{engine}, "pm" );

  my $file = join('.', join('/', split '::', __PACKAGE__), "pm" );
  my $path = $INC{$file};
  $path =~ s/\.pm//;
  opendir( my $dh, $path ) || die "Unable to open $path: $!\n";
  my( $db ) = grep { $_ eq  $engine } readdir $dh;
  closedir $dh;
  
  
  if( $db ) {
    $db =~ s/\.pm//;
    my $engine_class = join("::", __PACKAGE__, $db );
    eval qq( require $engine_class );
    die $@ if $@;
    #  $class->import();
    $dbh = $engine_class->new(@_);
    return $dbh;
  }
}

1;
