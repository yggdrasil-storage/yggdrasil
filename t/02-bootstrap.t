#!perl

# Test bootstrapping

use strict;
use warnings;

use Test::More;
use Yggdrasil;

unless( defined $ENV{YGG_ENGINE} ) {
    plan skip_all => q<Don't know how to connect to any storage engines>;
}

plan tests => 12;

# --- Create a new Yggdrasil
my $y = Yggdrasil->new();
isa_ok( $y, 'Yggdrasil', 'Yggdrasil->new()' );

my $s = $y->get_status();
isa_ok( $s, 'Yggdrasil::Status', 'Yggdrasil->get_status()' );
is( $s->status(), 200, 'Yggdrasil->new() completed' );

# --- Connect to Yggdrasil
my $c = $y->connect( engine    => $ENV{YGG_ENGINE},
		     host      => $ENV{YGG_HOST},
		     port      => $ENV{YGG_PORT},
		     db        => $ENV{YGG_DB},
		     user      => $ENV{YGG_USER},
		     password  => $ENV{YGG_PASSWORD},
		     bootstrap => 1
    );

is( $s->status(), 201, 'Yggdrasil->connect() completed' );
is( $c, 1, "connect()'s return value true" );

# --- Bootstrap Yggdrasil
my $boot = $y->bootstrap( testuser => 'secret' );

is( $s->status(), 200, 'Yggdrasil->bootstrap() completed' );
isa_ok( $boot, 'HASH', "bootstrap()'s return value ok" );
ok( exists $boot->{testuser}, "Has testuser" );
ok( exists $boot->{root}, "Has root user" );
is( $boot->{testuser}, "secret", "testusers password was secret" );

# --- Bootstrap Yggdrasil again
$boot = $y->bootstrap( me => 'even more secret' );
is( $s->status(), 406, 'Yggdrasil->bootstrap() has already been completed' );
is( $boot, undef, "bootstrap()'s return value ok" );
