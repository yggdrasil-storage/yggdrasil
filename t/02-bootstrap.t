#!perl

# Test bootstrapping

use strict;
use warnings;

use Test::More;
use lib qw(./t);
use Yggdrasil::Test::Common '12';

my $tester = Yggdrasil::Test::Common->new();

# --- Create a new Yggdrasil
my $ygg = $tester->new_yggdrasil();

# --- Connect to Yggdrasil
$tester->connect( bootstrap => 1 );

# --- Bootstrap Yggdrasil
my $boot = $ygg->bootstrap( testuser => 'secret' );

my $prefix = "Yggdrasil->bootstrap()";
ok( $tester->OK(), "$prefix: Completed with status " . $tester->code() . " " . $tester->status()->message() );
isa_ok( $boot, 'HASH', "$prefix: Return value isa HASH" );
ok( exists $boot->{testuser}, "$prefix: Has testuser" );
ok( exists $boot->{root}, "$prefix: Has root user" );
is( $boot->{testuser}, "secret", "$prefix: testusers password was secret" );

# --- Bootstrap Yggdrasil again
$boot = $ygg->bootstrap( me => 'even more secret' );
is( $tester->code(), 406, '$prefix: Has already been completed' );
is( $boot, undef, "$prefix: Return value ok" );
