#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Yggdrasil' );
}

diag( "Testing Yggdrasil $Yggdrasil::VERSION, Perl $], $^X" );
