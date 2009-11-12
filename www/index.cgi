#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib qw(/site/lib/perl);
use lib qq($Bin/../lib);

use Yggdrasil;
use Yggdrasil::Interface::WWW;

my $www = Yggdrasil::Interface::WWW->new();

my $user = $www->param('user');
my $pass = $www->param('pass');
my $sess = $www->cookie('sessionID');

my $y = Yggdrasil->new();
my $version = Yggdrasil->version();

$y->connect( user     => "yggdrasil", 
	     password => "beY6KAAVNbhPa6SP",

	     host   => "db.math.uio.no",
	     db     => "yggdrasil",
	     engine => "mysql",
    );
my $u = $y->login( user => $user, password => $pass, session => $sess );
unless( $u ) {
    $www->present_login( title => "Login", style => "yggdrasil.css", info => "(version $version / yggdrasil\@db.math.uio.no)" );
    exit;
}
$www->set_session( $u->session() );

my $mode   = $www->param('_mode');
my $ident  = $www->param('_identifier');
my $entity = $www->param('_entity');

$mode = undef unless defined $ident;

unless( $mode ) {
    my @e = $y->entities();
    my $c = $www->add( map { $_->name() } @e );
    $c->type( 'Entities' );
    $c->class( 'Entities' );

#    my $container1 = Yggdrasil::Inerface::Container->new( title => "Entities", class => "Entities" );
#    $container1->add(@e);
#    $www->add( $container1 );
    
    my @r = $y->relations();

    $c = $www->add(@r);
    $c->type( 'Relations' );
    $c->class( 'Relations' );
#    my $container2 = Yggdrasil::Inerface::Container->new( title => "Relations", class => "Relations" );
#    $container2->add(@r);
#    $www->add( $container2 );
    
    $www->display( title => "Yggdrasil", style => "yggdrasil.css" );

} elsif( $mode eq "entity" ) {
    my $e = $y->get_entity($ident);
    my @i = $e->instances();

    my $container = $www->add( map { $_->id() } @i );
    $container->type( 'Entity' );
    $container->class( 'Entity' );
    $container->parent( $ident );

    $www->display( title => "Instance of $ident", style => "yggdrasil.css" );

} elsif( $mode eq "relation" ) {
    my $r = $y->get_relation($ident);
    my @e = $r->entities();
    my @p = $r->participants();

    my $container = $www->add( map { $_->name() } @e );
    $container->type( 'Entities' );
    $container->class( 'Entities' );
    $container->parent( $ident );

    my $left  = $www->add();
    my $right = $www->add();

    foreach my $pair (@p) {
	my( $l, $r ) = @$pair;
	$left->add( $l->id() );
	$right->add( $r->id() );
    }

    $left->type( 'Entity' );
    $left->class( 'Entity' );
    $left->parent( $e[0]->name() );

    $right->type( 'Entity' );
    $right->class( 'Entity' );
    $right->parent( $e[1]->name() );

    $www->display( title => "Related instances for relation $ident", style => "yggdrasil.css" );

} elsif( $mode eq "instance" ) {
    my $e = $y->get_entity( $entity );
    my $i = $e->fetch( $ident );

    my @p;
    foreach my $prop ( $e->properties() ) {
	my $name = $prop->name();
	my $v = { property  => $name,
		  value     => $i->get($name),
		  _entity   => $entity,
		  _instance => $ident,
		  _id       => $name,
	};

	push( @p, $v );
    }


    my $container = $www->add( @p );
    $container->type( 'Instance' );
    $container->class( 'Instance' );
    my $title = "${entity}::$ident";
    $container->parent( $title );

    


    #my @r = $plugin->related( $entity, $ident );
    #$container = $www->add(@r );
    #$container->type( 'Related' );
    #$container->class( 'Related' );
    #$container->parent( "Relations" );


    $www->display( title => $title, style => "yggdrasil.css", script => 'yggdrasil.js' );
} 
