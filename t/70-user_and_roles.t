#!perl

use strict;
use warnings;

use Test::More;

use lib qw(./t);
use Yggdrasil::Test::Common '117';

my $tester = Yggdrasil::Test::Common->new();

# --- Initialize Yggdrasil
my $ygg = $tester->new_yggdrasil();

# --- Connect to Yggdrasil
$tester->connect();

# --- Authenticate
$tester->login();


# --- Define roles
my $sports = $tester->yggdrasil_define_role( "sports" );
my $colors = $tester->yggdrasil_define_role( "colors" );

# --- Define users
my $soccer = $tester->yggdrasil_define_user( "soccer" );
my $basket = $tester->yggdrasil_define_user( "basket" );
my $green  = $tester->yggdrasil_define_user( "green" );
my $white  = $tester->yggdrasil_define_user( "white" );

# --- Add users to roles
$tester->add_user_to_role( $colors, $white );
$tester->add_user_to_role( $colors, $green );

# --- Check role membership
$tester->check_role_members( $sports, [] );
$tester->check_role_members( $colors, ["green", "white"] );

# --- Add more users to roles
$tester->add_user_to_role( $sports, $basket );
$tester->add_user_to_role( $colors, $basket );

# --- Check user membership
$tester->check_user_membership( $soccer, [] );
$tester->check_user_membership( $basket, ["colors", "sports"] );

# --- Add same user to same role
$tester->add_user_to_role( $sports, $basket );
$tester->check_role_members( $sports, ["basket"] );
$tester->check_user_membership( $basket, ["sports", "colors"] );

# --- Remove users from roles
$tester->remove_user_from_role( $colors, $basket );
$tester->check_role_members( $colors, ["white", "green"] );
$tester->check_user_membership( $basket, ["sports"] );

# --- Remove same user from same role
$tester->remove_user_from_role( $colors, $basket );
$tester->check_role_members( $colors, ["white", "green"] );
$tester->check_user_membership( $basket, ["sports"] );

# --- Move white from colors to sports
$tester->remove_user_from_role( $colors, $white );
$tester->check_role_members( $colors, ["green"] );
$tester->check_user_membership( $white, [] );

$tester->add_user_to_role( $sports, $white );
$tester->check_role_members( $sports, ["basket", "white"] );
$tester->check_user_membership( $white, ["sports"] );

# --- Remove all user from the roles
$tester->remove_user_from_role( $colors, $green );
$tester->remove_user_from_role( $sports, $white );
$tester->remove_user_from_role( $sports, $basket );
$tester->check_role_members( $sports, [] );
$tester->check_user_membership( $white, [] );



