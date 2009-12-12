#!perl

use strict;
use warnings;

use Test::More;
use lib qw(./t);
use Yggdrasil::Test::Common '14';

my $Y    = 'Yggdrasil';
my $Y_Ro = 'Yggdrasil::Role';


my $tester = Yggdrasil::Test::Common->new();

# --- Initialize Yggdrasil
my $ygg = $tester->new_yggdrasil();

# --- Connect to Yggdrasil
$tester->connect();

# --- Authenticate
$tester->login();

# --- Define roles
my $br = $tester->yggdrasil_define_role( "bookreader" );

# --- Get name
is( $br->name(), "bookreader", "$Y_Ro->name(): Role name is bookreader" );

# --- Get role - existing
$br = $tester->yggdrasil_get_role( "bookreader" );

# --- Get role - non-existing
$br = $ygg->get_role( "doesn't exist" );
is( defined $br, '', "$Y->get_role(): correctly failed to fetch non-existant role" );
is( $tester->code(), 404, "$Y->get_role(): status() is 404" );

