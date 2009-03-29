#!perl

use strict;
use warnings;

use Test::More;
use Yggdrasil;

unless( defined $ENV{YGG_ENGINE} ) {
    plan skip_all => q<Don't know how to connect to any storage engines>;
}

plan tests => 90;

my $Y_PKG = "Yggdrasil";
my $Y_R_PKG = "Yggdrasil::Role";
my $Y_U_PKG = "Yggdrasil::User";
my $Y_S_PKG = "Yggdrasil::Status";

# --- Initialize Yggdrasil
my $ygg = Yggdrasil->new( debug => 0 );
isa_ok( $ygg, 'Yggdrasil', 'Yggdrasil->new()' );

my $s = $ygg->get_status();
isa_ok( $s, 'Yggdrasil::Status', 'Yggdrasil->get_status()' );
is( $s->status(), 200, 'Yggdrasil->new() completed' );

# --- Connect to Yggdrasil
my $c = $ygg->connect( engine    => $ENV{YGG_ENGINE},
		       host      => $ENV{YGG_HOST},
		       port      => $ENV{YGG_PORT},
		       db        => $ENV{YGG_DB},
		       user      => $ENV{YGG_USER},
		       password  => $ENV{YGG_PASSWORD},
    );

is( $s->status(), 200, 'Yggdrasil->connect() completed' );
is( $c, 1, "connect()'s return value true" );

# --- Authenticate
my $l = $ygg->login();
ok( $l, "Authenticated as $l" );
is( $s->status(), 200, 'Logged in' );

# --- Define roles
my $sports = $ygg->define_role( "sports" );
isa_ok( $sports, $Y_R_PKG, "$Y_PKG->define_role(): return value isa $Y_R_PKG" );
is( $sports->id(), "sports", "$Y_R_PKG->id(): return value is 'sports'" );

my $colors = $ygg->define_role( "colors" );
isa_ok( $colors, $Y_R_PKG, "$Y_PKG->define_role(): return value isa $Y_R_PKG" );
is( $colors->id(), "colors", "$Y_R_PKG->id(): return value is 'colors'" );

# --- Define users
my $soccer = $ygg->define_user( "soccer" );
isa_ok( $soccer, $Y_U_PKG, "$Y_PKG->define_role(): return value isa $Y_U_PKG" );
is( $soccer->id(), "soccer", "$Y_U_PKG->id(): return value is 'soccer'" );

my $basket = $ygg->define_user( "basket" );
isa_ok( $basket, $Y_U_PKG, "$Y_PKG->define_role(): return value isa $Y_U_PKG" );
is( $basket->id(), "basket", "$Y_U_PKG->id(): return value is 'basket'" );

my $green = $ygg->define_user( "green" );
isa_ok( $green, $Y_U_PKG, "$Y_PKG->define_role(): return value isa $Y_U_PKG" );
is( $green->id(), "green", "$Y_U_PKG->id(): return value is 'green'" );

my $white = $ygg->define_user( "white" );
isa_ok( $white, $Y_U_PKG, "$Y_PKG->define_role(): return value isa $Y_U_PKG" );
is( $white->id(), "white", "$Y_U_PKG->id(): return value is 'white'" );

# --- Add users to roles
my $r;
$r = $colors->add($white);
ok( $r, "$Y_R_PKG->add('white'): Added user to role" );

$r = $colors->add($green);
ok( $r, "$Y_R_PKG->add('green'): Added user to role" );

# --- Check role membership
check_members( $sports, [] );
check_members( $colors, ["green", "white"] );

# --- Add more users to roles
$r = $sports->add($basket);
ok( $r, "$Y_R_PKG->add('basket'): Added user to role" );

$r = $colors->add($basket);
ok( $r, "$Y_R_PKG->add('basket'): Added user to role" );

# --- Check user membership
check_member_of( $soccer, [] );
check_member_of( $basket, ["colors", "sports"] );

# --- Add same user to same role
$r = $sports->add($basket);
ok( $r, "$Y_R_PKG->add('basket'): Added user to role again" );
check_members( $sports, ["basket"] );
check_member_of( $basket, ["sports", "colors"] );

# --- Remove users from roles
$r = $colors->remove($basket);
is( $r, 1, "$Y_R_PKG->remove(): Removed 'basket' from 'colors'" );
check_members( $colors, ["white", "green"] );
check_member_of( $basket, ["sports"] );

# --- Remove same user from same role
$r = $colors->remove($basket);
is( $r, 1, "$Y_R_PKG->remove(): Removed 'basket' from 'colors' again" );
check_members( $colors, ["white", "green"] );
check_member_of( $basket, ["sports"] );

# --- Move white from colors to sports
$r = $colors->remove($white);
is( $r, 1, "$Y_R_PKG->remove(): Removed 'white' from 'colors'" );
check_members( $colors, ["green"] );
check_member_of( $white, [] );

$r = $sports->add($white);
ok( $r, "$Y_R_PKG->add(): Added 'white' to 'sports'" );
check_members( $sports, ["basket", "white"] );
check_member_of( $white, ["sports"] );



sub check_members {
    my $role = shift;
    my $expected_users = shift;

    my $n = @$expected_users;
    my $id = $role->id();

    my %eusers;
    @eusers{@$expected_users} = (1) x $n;

    my @u = $role->members();
    ok( @u == $n, "$Y_R_PKG->members(): $id has $n member" );

    foreach my $u (@u) {
	isa_ok( $u, $Y_U_PKG, "$Y_R_PKG->members(): return value is a $Y_U_PKG object" );
	my $uid = $u->id();
	ok( delete $eusers{$uid}, "$Y_R_PKG->members(): has member $uid" );
    }

    ok( ! keys %eusers, "$Y_R_PKG->members(): no unexpected members" );
}


sub check_member_of {
    my $user = shift;
    my $expected_roles = shift;

    my $n  = @$expected_roles;
    my $id = $user->id();

    my %eroles;
    @eroles{@$expected_roles} = (1) x $n;

    my @r = $user->member_of();
    ok( @r == $n, "$Y_U_PKG->member_of(): $id is member of $n roles" );

    foreach my $r (@r) {
	isa_ok( $r, $Y_R_PKG, "$Y_U_PKG->member_of(): return value is a $Y_R_PKG object" );

	my $rid = $r->id();
	ok( delete $eroles{$rid}, "$Y_U_PKG->member_of(): member of $rid" );
    }

    ok( ! keys %eroles, "$Y_U_PKG->member_of(): not member of any unexpected roles" );
}
