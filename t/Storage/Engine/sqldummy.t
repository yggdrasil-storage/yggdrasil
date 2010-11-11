#!perl

use strict;
use warnings;

use Test::More;

use lib qw(t);

use Storage;
use Test::Resources;
use Data::Dumper;

my $resources = Test::Resources->new();
my $answers = $resources->parse_tests( *DATA );

BEGIN { use_ok( 'Storage::Engine::sqldummy' ) }

my $dummy = Storage->new( engine => 'sqldummy' );


my $defines = $resources->get_tests( 'SQL/define' );
for my $name ( keys %$defines ) {
    my @test = eval( $defines->{$name} );
    my $expected = $answers->{$name};

    my( $sql, $indexes ) = $dummy->_generate_define_sql( @test );
    is( $sql, $expected, $name );
}

done_testing();

__DATA__
Test general define sql building
-- 
CREATE TABLE TEST-SCHEMA (
field1 TEXT NULL ,
field2 INTEGER NOT NULL ,
PRIMARY KEY (field1)) ;
-- 
Testing SERIAL and field named 'id'
-- 
CREATE TABLE TEST-SCHEMA (
id INTEGER NULL ,
field1 SERIAL NULL ) ;
