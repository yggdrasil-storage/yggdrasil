#!perl

use strict;
use warnings;

use lib qw(./t);
use Yggdrasil::Test::Common '176';

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
my $ip = $tester->entity_define_property( $host, 'ip' );

# --- Create Instances
my $laptop = $tester->create_instance( $host, "My Laptop" );
my $closet = $tester->create_instance( $room, "Closet" );

# --- Set Property
$tester->set_instance_property( $laptop, ip => '127.0.0.1' );

# --- Define Relation 'Host' <=> 'Room'
my $h_r = $tester->yggdrasil_define_relation( $host, $room );

# --- Link
$h_r->link( $laptop, $closet );
$tester->fetch_related( $closet, $host, ["My Laptop"] );
$tester->fetch_related( $laptop, $room, ["Closet"] );

# --- unlink
$h_r->unlink( $laptop, $closet );
$tester->fetch_related( $closet, $host, [] );
$tester->fetch_related( $laptop, $room, [] );

# --- Complex Relations
$room        = $tester->yggdrasil_define_entity( "Room" );
$host        = $tester->yggdrasil_define_entity( "Host" );
my $person   = $tester->yggdrasil_define_entity( "Person" );
my $phone    = $tester->yggdrasil_define_entity( "Phone" );
my $provider = $tester->yggdrasil_define_entity( "Provider" );

my( %boys, %girls );
$girls{$_} = $tester->create_instance($person, $_) for qw/Sandy Mindy Cindy/;
$boys{$_}  = $tester->create_instance($person, $_) for qw/Mark Clark/;

my %phones;
$phones{$_} = $tester->create_instance($phone, $_) for qw/555-0001 555-1000 555-1234 555-9999/;

my %providers;
$providers{$_} = $tester->create_instance($provider, $_) for qw/TelSat SuperPhone/;

my %rooms;
$rooms{$_} = $tester->create_instance($room, $_) for qw/NerdLab Aquarium/;

my %hosts;
$hosts{$_} = $tester->create_instance($host, $_) for qw/cod salmon herring hopper lovelace/;


$h_r = $tester->yggdrasil_define_relation( $host, $room );
my $p_h = $tester->yggdrasil_define_relation( $person, $host );
my $r_p = $tester->yggdrasil_define_relation( $room, $phone );
my $p_p = $tester->yggdrasil_define_relation( $phone, $provider );

$p_h->link( $girls{Sandy}, $hosts{cod} );
$p_h->link( $girls{Mindy}, $hosts{salmon} );
$p_h->link( $girls{Cindy}, $hosts{herring} );
$p_h->link( $boys{Mark}, $hosts{hopper} );
$p_h->link( $boys{Clark}, $hosts{lovelace} );

$h_r->link( $hosts{cod}, $rooms{Aquarium} );
$h_r->link( $hosts{salmon}, $rooms{Aquarium} );
$h_r->link( $hosts{herring}, $rooms{Aquarium} );
$h_r->link( $hosts{hopper}, $rooms{NerdLab} );
$h_r->link( $hosts{lovelace}, $rooms{NerdLab} );

$r_p->link( $rooms{NerdLab}, $phones{'555-0001'} );
$r_p->link( $rooms{NerdLab}, $phones{'555-1000'} );
$r_p->link( $rooms{Aquarium}, $phones{'555-1234'} );
$r_p->link( $rooms{Aquarium}, $phones{'555-9999'} );

$p_p->link( $phones{'555-0001'}, $providers{TelSat} );
$p_p->link( $phones{'555-1000'}, $providers{TelSat} );
$p_p->link( $phones{'555-1234'}, $providers{SuperPhone} );
$p_p->link( $phones{'555-9999'}, $providers{SuperPhone} );


# --- On what numbers can the girls be reached?
for my $name ( keys %girls ) {
    my $girl = $girls{$name};
    my @v = $tester->fetch_related( $girl, $phone, [qw/555-1234 555-9999/] );
}

# --- Who can be reached by calling 555-1000?
my @v = $tester->fetch_related( $phones{'555-1000'}, $person, [qw/Mark Clark/] );

# --- Can't reach Mindy, all phones dead. Which provider to contact?
@v = $tester->fetch_related( $girls{Mindy}, $provider, ["SuperPhone"] );

# --- Sandy get a personal phone
my $p_t = $tester->yggdrasil_define_relation( $person, $phone );
$phones{'555-Sandy'} = $tester->create_instance($phone, '555-Sandy');
$p_t->link( $girls{Sandy}, $phones{'555-Sandy'} );

# --- On what numbers can we reach Sandy?
@v = $tester->fetch_related( $girls{Sandy}, $phone, [qw/555-1234 555-9999 555-Sandy/] );

# --- Sandy drops new phone into the toilet
$p_p->unlink( $girls{Sandy}, $phones{'555-Sandy'} );
@v = $tester->fetch_related( $girls{Sandy}, $phone, [qw/555-1234 555-9999/] );
