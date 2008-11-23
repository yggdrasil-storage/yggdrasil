#!perl

use Test::More;
use Yggdrasil;

use strict;
use warnings;

unless( defined $ENV{YGG_ENGINE} ) {
    plan skip_all => q<Don't know how to connect to any storage engines>;
}

plan tests => 6;

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

# --- Define Entitis 'A', 'B', 'AA', 'BB'
my $A  = define Yggdrasil::Entity 'A';
my $B  = define Yggdrasil::Entity 'B', inherit => 'A';
my $AA = define Yggdrasil::Entity 'AA';
my $BB = define Yggdrasil::Entity 'BB', inherit => 'AA';

# --- Define Property 'foo' for Entity 'A'
my $foo = define $A 'foo';

# --- Create Instances
my $i_a  = $A->new( "A" );
my $i_b  = $B->new( "B" );
my $i_aa = $AA->new( "AA" );
my $i_bb = $BB->new( "BB" );

$i_a->property( $foo => "A.foo" );
is( $i_a->property( $foo ), "A.foo" );

$i_b->property( $foo => "B.foo" );
is( $i_b->property( $foo ), "B.foo" );

# -- Define Relation 'double'
my $double = define Yggdrasil::Relation $A, $AA, label => "double";
$double->link( $i_a, $i_aa );
my @other = $i_a->fetch_related( "AA" );
ok( @other == 1, "Found 1 other AA" );
isa_ok( $other[0], $AA, "Other isa $AA" );
is( $other[0]->id(), "AA", "Other->id() == AA" );

#$double->link( $i_b, $i_bb );
#@other = $i_b->fetch_related( "BB" );
#ok( @other == 1, "Found 1 other BB" );
#isa_ok( $other[0], $BB, "Other isa $BB" );
#is( $other[0]->id(), "BB", "Other->id() == BB" );

