#!perl

use strict;
use warnings;

use Test::More;
use Yggdrasil;

unless( defined $ENV{YGG_ENGINE} ) {
    plan skip_all => q<Don't know how to connect to any storage engines>;
}

plan tests => 14;

# --- Initialize Yggdrasil
my $ygg = Yggdrasil->new();
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

# --- Define Entity 'Host'
my $host = $ygg->define_entity( 'Host' );
isa_ok( $host, "Yggdrasil::Entity", "defined 'Host'" );
is( $host->name(), 'Host', "Name is 'Host'" );
is( $s->status(), 201, "Created entity 'Host'" );

# --- Define Property 'ip' for Entity 'Host'
my $ip = $host->define_property( 'ip' );
isa_ok( $ip, "Yggdrasil::Property", "defined 'Host:ip'" );
is( $ip->name(), 'ip', "name is 'ip'" );
is( $ip->full_name(), 'Host:ip', "full name is 'Host:ip'" );
is( $s->status(), 201, "Created property 'Host:ip'" );

