#!perl

# Test bootstrapping

use strict;
use warnings;

use Test::More;
use lib qw(./t);
use Yggdrasil::Test::Common '13';

my $tester = Yggdrasil::Test::Common->new();

# --- Create a new Yggdrasil
my $ygg = $tester->new_yggdrasil();

# --- Connect to Yggdrasil
$tester->connect( bootstrap => 1 );

# --- Bootstrap Yggdrasil
my $boot = $tester->bootstrap( testuser => 'secret' );

my $prefix = "Yggdrasil->bootstrap()";
if( $tester->OK() ) {
    ok( exists $boot->{testuser}, "$prefix: Has testuser" );
    is( $boot->{testuser}, "secret", "$prefix: testusers password was secret" );
} else {
    ok( 1, "$prefix: dummy test" );
    ok( 1, "$prefix: dummy test" );
}

# --- Bootstrap Yggdrasil again
$tester->bootstrap( me => 'even more secret' );
