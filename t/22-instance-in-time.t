#!perl

use strict;
use warnings;

use Test::More;

use lib qw(./t);
use Yggdrasil::Test::Common '69';

my $Y_E_I = "Yggdrasil::Instance";

my $tester = Yggdrasil::Test::Common->new();

# --- Initialize Yggdrasil
my $ygg = $tester->new_yggdrasil();

# --- Connect to Yggdrasil
$tester->connect();

# --- Authenticate
$tester->login();

# --- Define entity
my $host = $tester->yggdrasil_define_entity( 'Host' );

# --- Define property
my $ip = $tester->entity_define_property( $host, "ip" );

# --- Create instance
my $hal = $tester->create_instance( $host, "HAL" );

# --- Setup property
my @time;
my @values =  qw/0.0.0.0 10.20.30.40 255.255.255.255/;
for my $val (@values) {
    $tester->set_instance_property( $hal, ip => $val );
    push( @time, time() );
    sleep 2;
}

# --- Test get-in-time -- get at time
my $n = 0;
for my $val (@values) {
    my @hal_in_time = $tester->get_instance( $host, "HAL", 1, $time[$n] );
    my $ip = $hal_in_time[0]->get( "ip" );
    check_property_return( $ip, $val );
} continue { $n++ }


# --- Test get-in-time -- get time slice
for $n (0..1) {
    my @hal_in_time = $tester->get_instance( $host, "HAL", 2, $time[$n], $time[$n+1] + 1 );

    my $x = 0;
    for my $h (@hal_in_time) {
	my $ip = $h->get("ip");
	check_property_return( $ip, $values[$n+$x] );
    } continue { $x++ }
}


sub check_property_return {
    my $val = shift;
    my $expected = shift;

    ok( $tester->OK(), "$Y_E_I->get(): Fetched property 'ip' in time with status " . $tester->code() );
    is( $val, $expected, "$Y_E_I->get(): Return value was ($val)" );
}
