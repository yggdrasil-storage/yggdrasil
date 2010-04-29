package Storage::Mapper::SHA1;

use strict;
use warnings;

use Digest::SHA1 qw(sha1_hex);

sub new {
    my $class = shift;
    my $self  = {};
    
    return bless $self, $class;
}


sub map :method {
    my $self  = shift;
    my $tomap = shift;
    
    my $digest = sha1_hex( $tomap );
    $digest =~ y/0-9a-f/a-p/;
    return $digest;
}

1;
