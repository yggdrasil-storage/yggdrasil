#!perl

use strict;
use warnings;

use Test::More;

use lib qw(./t);
use Yggdrasil::Test::Common '30';

my $Y   = 'Yggdrasil';
my $Y_U = 'Yggdrasil::User';


my $tester = Yggdrasil::Test::Common->new();

# --- Initialize Yggdrasil
my $ygg = $tester->new_yggdrasil();

# --- Connect to Yggdrasil
$tester->connect();

# --- Authenticate
$tester->login();

# --- Define users - Without password
my $haxor = $tester->yggdrasil_define_user( "haxor" );

# --- Define users - With password
my $r00t = $tester->yggdrasil_define_user( "r00t", password => "123A56" );

# --- Set/Get password
my $r = $haxor->password("fubar");
is( $r, "fubar", "$Y_U->password(): return value was $r" );
is( $haxor->password(), "fubar", "$Y_U->password(): can change haxor's password" );

# --- Set/Get fullname
$r = $r00t->fullname( "Rob T.");
is( $r, "Rob T.", "$Y_U->fullname(): return value was $r" );
is( $r00t->fullname(), "Rob T.", "$Y_U->fullname(): can set/get r00t's fullname (to Rob T.)" );

# --- Set/Get session
$r = $haxor->session( "zxzx" );
is( $r, "zxzx", "$Y_U->session(): return value was $r" );

is( $haxor->session(), "zxzx", "$Y_U->session(): can set/get haxor's session" );

# --- Get username
is( $haxor->username(), "haxor", "$Y_U->username(): can set/get haxor's username" );

# --- Get id
$r = $r00t->id();
is( $r, "r00t", "$Y_U->id(): return value was $r" );
$r = $haxor->id();
is( $r, "haxor", "$Y_U->id(): return value was $r" );

# --- Get user - existing
$r00t = $tester->yggdrasil_get_user( "haxor" );
#$r00t = $ygg->get_user( "haxor" );
#isa_ok( $r00t, $Y_U_PKG, "$Y->get_user(): Return value" );
#is( $r00t->id(), "haxor", "$Y_U->id(): we are haxor" );
is( $r00t->username(), "haxor", "$Y_U->username(): we are haxor" );

# --- Get user - non-existing
$r00t = $ygg->get_user( "doesn't exist" );
is( defined $r00t, '', "$Y->get_user(): correctly failed to fetch non-existant user" );
is( $tester->code(), 404, "$Y->get_user(): status() is 404" );
