package Yggdrasil::Storage::Mapper::MD5;

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);

sub new {
    my $class = shift;
    my $self  = {};
    
    return bless $self, $class;
}


sub map :method {
    my $self  = shift;
    my $tomap = shift;
    
    my $digest = md5_hex( $tomap );
    $digest =~ y/0-9a-f/a-p/;
    return $digest;
}

1;
