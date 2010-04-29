package Storage::Type::Filter::SHA;

use strict;
use warnings;

use Digest::SHA;

sub fetch {
    my $class = shift;
    return shift;
}

sub store {
    my $class = shift;
    my ($string, $shaversion) = @_;
    return unless defined $string;
    return Digest::SHA::sha1_hex( $string ) unless $shaversion;
    
    if ($shaversion =~ /224$/) {
	return Digest::SHA::sha224_hex( $string );
    } elsif ($shaversion =~ /256$/) {
	return Digest::SHA::sha256_hex( $string );
    } elsif ($shaversion =~ /384$/) {
	return Digest::SHA::sha384_hex( $string );
    } elsif ($shaversion =~ /512$/) {
	return Digest::SHA::sha512_hex( $string );
    } else {
	return Digest::SHA::sha1_hex( $string );
    }
}

1;
