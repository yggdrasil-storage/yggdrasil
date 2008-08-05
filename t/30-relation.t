#!perl

use Test::More;
use Yggdrasil;

use strict;
use warnings;

unless( defined $ENV{YGG_ENGINE} ) {
    plan skip_all => q<Don't know how to connect to any storage engines>;
}

plan tests => 35;

# --- Initialize Yggdrasil
my $ygg;
my $space = 'Ygg';
eval {
    $ygg = Yggdrasil->new( namespace => $space,
			   engine    => $ENV{YGG_ENGINE},
			   db        => $ENV{YGG_DB},
			   user      => $ENV{YGG_USER},
			   password  => $ENV{YGG_PASSWORD},
			   host      => $ENV{YGG_HOST},
			   port      => $ENV{YGG_PORT} );
};

isa_ok( $ygg, 'Yggdrasil', 'Yggdrasil->new()' );

# --- Define Entity 'Host'
my $host = define Yggdrasil::Entity 'Host';
is( $host, "$space\::Host", "define 'Host'" );
ok( exists $::{"$space\::"}{"Host::"}, "package $host" );

# --- Define Entity 'Room'
my $room = define Yggdrasil::Entity 'Room';
is( $room, "$space\::Room", "define 'Room'" );
ok( exists $::{"$space\::"}{"Room::"}, "package $room" );

# --- Define Property 'ip' for Entity 'Host'
my $ip = define $host 'ip';
is( $ip, 'ip', "define 'ip'" );

# --- Create Instances
my $laptop = $host->new( "My Laptop" );
isa_ok( $laptop, $host, "$host->new()" );
is( $laptop->id(), "My Laptop", "($host instance)->id()" );

my $closet = $room->new( "Closet" );
isa_ok( $closet, $room, "$room->new()" );
is( $closet->id(), "Closet", "($room instance)->id()" );

# --- Set Property
$laptop->property( $ip => '127.0.0.1' );
is( $laptop->property( $ip ), '127.0.0.1', "($host instance)->property($ip)" );

# --- Define Relation 'Host' <=> 'Room'
define Yggdrasil::Relation $host, $room;
$laptop->link( $closet );
my @host = $closet->fetch_related( $host );
ok( @host == 1, "1 host in the closet" );
isa_ok( $host[0], $host, "host in the closet" );
is( $host[0]->id(), "My Laptop", "Laptop is in the closet" );

my @room = $laptop->fetch_related( $room );
ok( @room == 1, "laptop in 1 room" );
isa_ok( $room[0], $room, "room containing 1 host" );
is( $room[0]->id(), "Closet", "closet contains laptop" );

# --- unlink
$closet->unlink( $laptop );
@host = $closet->fetch_related( $host );
ok( @host == 0, "after unlink; Closet is empty" );

@room = $laptop->fetch_related( $room );
ok( @room == 0, "after unlink; Laptop is nowhere to be found" );


# --- Complex Relations
$room = define Yggdrasil::Entity 'Room';
$host = define Yggdrasil::Entity 'Host';
my $person   = define Yggdrasil::Entity 'Person';
my $phone    = define Yggdrasil::Entity 'Phone';
my $provider = define Yggdrasil::Entity 'Provider';

my( %boys, %girls );
$girls{$_} = $person->new($_) for qw/Sandy Mindy Cindy/;
$boys{$_}  = $person->new($_) for qw/Mark Clark/;

my %phones;
$phones{$_} = $phone->new($_) for qw/555-0001 555-1000 555-1234 555-9999/;

my %providers;
$providers{$_} = $provider->new($_) for qw/TelSat SuperPhone/;

my %rooms;
$rooms{$_} = $room->new($_) for qw/NerdLab Aquarium/;

my %hosts;
$hosts{$_} = $host->new($_) for qw/cod salmon herring hopper lovelace/;


define Yggdrasil::Relation $person, $host;
define Yggdrasil::Relation $host, $room;
define Yggdrasil::Relation $room, $phone;
define Yggdrasil::Relation $phone, $provider;

$girls{Sandy}->link( $hosts{cod} );
$girls{Mindy}->link( $hosts{salmon} );
$girls{Cindy}->link( $hosts{herring} );
$boys{Mark}->link( $hosts{hopper} );
$boys{Clark}->link( $hosts{lovelace} );

$hosts{cod}->link( $rooms{Aquarium} );
$hosts{salmon}->link( $rooms{Aquarium} );
$hosts{herring}->link( $rooms{Aquarium} );
$hosts{hopper}->link( $rooms{NerdLab} );
$hosts{lovelace}->link( $rooms{NerdLab} );

$rooms{NerdLab}->link( $phones{'555-0001'} );
$rooms{NerdLab}->link( $phones{'555-1000'} );
$rooms{Aquarium}->link( $phones{'555-1234'} );
$rooms{Aquarium}->link( $phones{'555-9999'} );

$phones{'555-0001'}->link( $providers{TelSat} );
$phones{'555-1000'}->link( $providers{TelSat} );
$phones{'555-1234'}->link( $providers{SuperPhone} );
$phones{'555-9999'}->link( $providers{SuperPhone} );

# --- On what numbers can the girls be reached?
for my $name ( keys %girls ) {
    my $girl = $girls{$name};
    my @v = $girl->fetch_related( $phone );
    ok( @v == 2, "$name can be reached with two phone numbers" );
    ok( (grep { $_->id() eq '555-1234' } @v), "$name can be reached with 555-1234" );
    ok( (grep { $_->id() eq '555-9999' } @v), "$name can be reached with 555-9999" );
}

# --- Who can be reached by calling 555-1000?
my @v = $phones{'555-1000'}->fetch_related( $person );
ok( @v == 2, "Two people can be reached by calling 555-1000" );
ok( (grep { $_->id() eq 'Mark' } @v), "Mark can be reached by 555-1000" );
ok( (grep { $_->id() eq 'Clark' } @v), "Clark can be reached by 555-1000" );

# --- Can't reach Mindy, all phones dead. Which provider to contact?
@v = $girls{Mindy}->fetch_related( $provider );
ok( @v == 1, "One provider for phones related to Mindy" );
is( $v[0]->id(), "SuperPhone", "SuperPhone provides phone service for phones in rooms where Mindy hangs out" );


# --- Sandy get a personal phone
define Yggdrasil::Relation $person, $phone;
$phones{'555-Sandy'} = $phone->new('555-Sandy');
$phones{'555-Sandy'}->link( $girls{Sandy} );
    
# --- On what numbers can we reach Sandy?
@v = $girls{Sandy}->fetch_related( $phone );
ok( @v == 3, "Sandy can now be reached with three numbers" );
ok( (grep { $_->id() eq '555-Sandy' } @v), "and one of the numbers are 555-Sandy" );

