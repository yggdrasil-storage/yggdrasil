#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib qq($Bin/../lib);

use Yggdrasil;
use Yggdrasil::Interface::WWW;

my $www = Yggdrasil::Interface::WWW->new();

my $user = $www->param('user');
my $pass = $www->param('pass');
my $sess = $www->cookie('sessionID');

my $y = Yggdrasil->new();

$y->connect( user     => "", 
	     password => "",

	     host   => "localhost",
	     db     => "yggdrasil",
	     engine => "mysql",
    );

my $u = $y->login( user => $user, password => $pass, session => $sess );
unless( $u ) {
    $www->present_login( title => "Login", style => "yggdrasil.css" );
    exit;
}

if( defined $user && defined $pass ) {
    # FIX: Yggdrasil->user() should return a user-object.
    my $mau_e = $y->get_entity( 'MetaAuthUser' );
    my $mau_i = $mau_e->fetch( $u );
    my $session = $mau_i->get( "session" );

    $www->set_session( $session );
}

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






