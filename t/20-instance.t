#!perl

use Test::More;
use Yggdrasil;

use strict;
use warnings;

unless( defined $ENV{YGG_ENGINE} ) {
    plan skip_all => q<Don't know how to connect to any storage engines>;
}

plan tests => 11;

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
