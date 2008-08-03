#!perl

use Test::More;
use Yggdrasil;

use strict;
use warnings;

unless( defined $ENV{YGG_ENGINE} ) {
    plan skip_all => q<Don't know how to connect to any storage engines>;
}

plan tests => 4;

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

# --- Define Property 'ip' for Entity 'Host'
my $ip = define $host 'ip';
is( $ip, 'ip', "define 'ip'" );

