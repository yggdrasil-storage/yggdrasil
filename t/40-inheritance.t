#!perl

use strict;
use warnings;

use lib qw(./t);
use Yggdrasil::Test::Common '51';

my $tester = Yggdrasil::Test::Common->new();

# --- Initialize Yggdrasil
my $ygg = $tester->new_yggdrasil();

# --- Connect to Yggdrasil
$tester->connect();

# --- Authenticate
$tester->login();

# --- Define Entitis 'A', 'B', 'AA', 'BB'
my $A  = $tester->yggdrasil_define_entity( "A" );
my $B  = $tester->yggdrasil_define_entity( "B", inherit => "A" );
my $AA = $tester->yggdrasil_define_entity( "AA" );
my $BB = $tester->yggdrasil_define_entity( "BB", inherit => "AA" );

# --- Define Property 'foo' for Entity 'A'
my $foo = $tester->entity_define_property( $A, "foo" );

# --- Create Instances
my $i_a  = $tester->create_instance( $A, "A" );
my $i_b  = $tester->create_instance( $B, "B" );
my $i_aa = $tester->create_instance( $AA, "AA" );
my $i_bb = $tester->create_instance( $BB, "BB" );

$tester->set_instance_property( $i_a, "foo", "A.foo" );
$tester->set_instance_property( $i_b, "foo", "B.foo" );

# -- Define Relation 'double'
my $double = $tester->yggdrasil_define_relation( $A, $AA, label => "double" );
$double->link( $i_a, $i_aa );
my @other = $tester->fetch_related( $i_a, $AA, ["AA"] );

#$double->link( $i_b, $i_bb );
#@other = $tester->fetch_related( $i_b, $BB, ["BB"] );

