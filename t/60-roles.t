#!perl

use strict;
use warnings;

use Test::More;
use Yggdrasil;

unless( defined $ENV{YGG_ENGINE} ) {
    plan skip_all => q<Don't know how to connect to any storage engines>;
}

plan tests => 16;

my $Y_PKG = "Yggdrasil";
my $Y_R_PKG = "Yggdrasil::Role";
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

# --- Define roles
my $br = $ygg->define_role( "bookreaders" );
isa_ok( $br, $Y_R_PKG, "$Y_PKG->define_role(): defined roles 'bookreaders'" );
is( $br->id(), "bookreaders", "$Y_R_PKG->id(): bookreaders are bookreaders" );

# --- Set/Get name
my $r = $br->name( "bbb" );
is( $r, "bbb", "$Y_R_PKG->name('bbb'): return value was $r" );
is( $br->name(), "bbb", "$Y_R_PKG->name(): roles name is bbb" );

# --- Get role
$br = $ygg->get_role( "doesn't exist" );
is( defined $br, '', "$Y_PKG->get_role('doesn't exist'): correctly failed to fetch non-existant role" );
is( $s->status(), 404, "status() is 404" );

$br = $ygg->get_role( "bookreaders" );
isa_ok( $br, $Y_R_PKG, "$Y_PKG->get_role('bookreaders'): isa $Y_R_PKG" );
is( $br->id(), "bookreaders", "$Y_R_PKG->id(): we are bookreaders" );
is( $br->name(), "bbb", "$Y_R_PKG->name(): we are bbb" );
