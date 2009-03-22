#!perl

use Test::More tests => 1;

# Test use
BEGIN {	use_ok( 'Yggdrasil' ) }
diag( "Testing Yggdrasil $Yggdrasil::VERSION, Perl $], $^X" );
