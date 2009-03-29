#!perl

use strict;
use warnings;

use lib qw(./t);
use Yggdrasil::Test::Common '27';

my $tester = Yggdrasil::Test::Common->new();

# --- Initialize Yggdrasil
my $ygg = $tester->new_yggdrasil();

# --- Connect to Yggdrasil
$tester->connect();

# --- Authenticate
$tester->login();

# --- Define Entity 'Host'
my $host = $tester->yggdrasil_define_entity( 'Host' );

# --- Define Entity 'Room'
my $room = $tester->yggdrasil_define_entity( 'Room' );

# --- Define Property 'ip' for Entity 'Host'
my $ip = $tester->entity_define_property( $host, "ip" );

# --- Create Instances
my $laptop = $tester->create_instance( $host, "My Laptop" );
my $closet = $tester->create_instance( $room, "Closet" );

# --- Set Property
$tester->set_instance_property( $laptop, "ip", "127.0.0.1" );
