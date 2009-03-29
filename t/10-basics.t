#!perl

use strict;
use warnings;

use lib qw(./t);
use Yggdrasil::Test::Common '14';

my $tester = Yggdrasil::Test::Common->new();

# --- Initialize Yggdrasil
my $ygg = $tester->new_yggdrasil();

# --- Connect to Yggdrasil
$tester->connect();

# --- Authenticate
$tester->login();

# --- Define Entity 'Host'
my $host = $tester->yggdrasil_define_entity( 'Host' );

# --- Define Property 'ip' for Entity 'Host'
my $ip = $tester->entity_define_property( $host, 'ip' );
