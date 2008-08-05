package Yggdrasil::Storage;

use strict;
use warnings;

our $storage;

sub new {
  my $class = shift;
  my $self  = {};
  my %data = @_;

  return $storage if $storage;

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
    $storage = $engine_class->new(@_);

    $storage->{logger} = Yggdrasil::get_logger( ref $storage );
    
    return $storage;
  }
}

1;
