package Storage::Type::Filter::MD5;

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);

sub fetch {
    return shift;
}

sub store {
    my $class = shift;
    return md5hex( shift );
}

1;
