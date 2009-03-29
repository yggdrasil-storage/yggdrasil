#!perl

use strict;
use warnings;

use Test::More;
use Yggdrasil;

unless( defined $ENV{YGG_ENGINE} ) {
    plan skip_all => q<Don't know how to connect to any storage engines>;
}

plan tests => 28;

my $Y_PKG = "Yggdrasil";
my $Y_U_PKG = "Yggdrasil::User";
my $Y_S_PKG = "Yggdrasil::Status";

# --- Initialize Yggdrasil
my $ygg = Yggdrasil->new();
isa_ok( $ygg, $Y_PKG, "$Y_PKG->new(): returned object was of type $Y_PKG" );

my $s = $ygg->get_status();
isa_ok( $s, $Y_S_PKG, "$Y_PKG->get_status(): returned object was of type $Y_S_PKG" );
is( $s->status(), 200, "$Y_PKG->new(): completed with status 200" );

# --- Connect to Yggdrasil
my $c = $ygg->connect( engine    => $ENV{YGG_ENGINE},
		       host      => $ENV{YGG_HOST},
		       port      => $ENV{YGG_PORT},
		       db        => $ENV{YGG_DB},
		       user      => $ENV{YGG_USER},
		       password  => $ENV{YGG_PASSWORD},
    );

is( $s->status(), 200, "$Y_PKG->connect(): completed with status 200" );
is( $c, 1, "$Y_PKG->connect(): return value true" );

# --- Authenticate
my $l = $ygg->login();
ok( $l, "$Y_PKG->login(): Authenticated as $l" );
is( $s->status(), 200, "$Y_PKG->login(): Logged in" );

# --- Define users
# --- Without password
my $haxor = $ygg->define_user( "haxor" );
isa_ok( $haxor, $Y_U_PKG, "$Y_PKG->define_user(): defined user haxor" );
is( $haxor->id(), "haxor", "$Y_U_PKG->id(): haxor is haxor" );
ok( length($haxor->password())==12, "$Y_U_PKG->password(): haxor got a password of length 12" );

# --- With password
my $r00t  = $ygg->define_user( "r00t", password => "123A56" );
isa_ok( $r00t, $Y_U_PKG, "$Y_PKG->define_user(): defined user r00t" );
is( $r00t->id(), "r00t", "$Y_U_PKG->id(): r00t is r00t" );
is( $r00t->password(), "123A56", "$Y_U_PKG->password(): r00t's password is 123A56" );

# --- Set/Get password
my $r = $haxor->password("fubar");
is( $r, "fubar", "$Y_U_PKG->password('fubar'): return value was $r" );
is( $haxor->password(), "fubar", "$Y_U_PKG->password(): can change haxor's password" );

# --- Set/Get fullname
$r = $r00t->fullname( "Rob T.");
is( $r, "Rob T.", "$Y_U_PKG->fullname('Rob T.'): return value was $r" );
is( $r00t->fullname(), "Rob T.", "$Y_U_PKG->fullname(): can set/get r00t's fullname (to Rob T.)" );

# --- Set/Get session
$r = $haxor->session( "zxzx" );
is( $r, "zxzx", "$Y_U_PKG->session('zxzx'): return value was $r" );
is( $haxor->session(), "zxzx", "$Y_U_PKG->session(): can set/get haxor's session" );

# --- Set/Get username
$r = $haxor->username( "bambi" );
is( $r, "bambi", "$Y_U_PKG->username('bambi'): return value was $r" );
is( $haxor->username(), "bambi", "$Y_U_PKG->username(): can set/get haxor's username" );

# --- Get id
$r = $r00t->id();
is( $r, "r00t", "$Y_U_PKG->id(): return value was $r" );
$r = $haxor->id();
is( $r, "haxor", "$Y_U_PKG->id(): return value was $r" );

# --- Get user
$r00t = $ygg->get_user( "haxor" );
isa_ok( $r00t, $Y_U_PKG, "$Y_PKG->get_user('haxor'): isa $Y_U_PKG" );
is( $r00t->id(), "haxor", "$Y_U_PKG->id(): we are haxor" );
is( $r00t->username(), "bambi", "$Y_U_PKG->username(): we are bambi" );

$r00t = $ygg->get_user( "doesn't exist" );
is( defined $r00t, '', "$Y_PKG->get_user('doesn't exist'): correctly failed to fetch non-existant user" );
is( $s->status(), 404, "status() is 404" );
