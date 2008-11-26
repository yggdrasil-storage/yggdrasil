#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib qq(/site/lib/perl);
use lib qq($Bin/../lib);

use Yggdrasil::Auth;
use Yggdrasil::Plugin;
use Yggdrasil::Plugin::Property::Prioritize;
use Yggdrasil::Interface::WWW;

use CGI::Pretty;

my $plugin = Yggdrasil::Plugin->new( 
				    user      => $ENV{YGG_USER},
				    password  => $ENV{YGG_PASSWORD},
				    host      => $ENV{YGG_HOST},
				    port      => $ENV{YGG_PORT}|| 3306, 
				    db        => $ENV{YGG_DB} || "yggdrasil",
				    engine    => $ENV{YGG_ENGINE} || "mysql",
				    namespace => 'Ygg',
				   );

my $pp   = Yggdrasil::Plugin::Property::Prioritize->new( level => 500 );
my $auth = new Yggdrasil::Auth;

$plugin->add( $pp );

my $www = new Yggdrasil::Interface::WWW;
my $cgi = CGI::Pretty->new();

my $user = $cgi->param('user');
my $pass = $cgi->param('pass');
my $sess = $cgi->cookie('sessionID');
my $session = $auth->authenticate( user => $user, pass => $pass, session => $sess );

if( defined $user && defined $pass ) {
    $www->set_session( $session );
}

unless( $session ) {
    $www->present_login( title => "Login", style => "yggdrasil.css" );
    exit;
} 


my $mode   = $cgi->param('_mode');
my $ident  = $cgi->param('_identifier');
my $entity = $cgi->param('_entity');

$mode = undef unless defined $ident;

unless( $mode ) {
    my @e = $plugin->entities();
    my $container = $www->add( @e );
    $container->type( 'Entities' );
    $container->class( 'Entities' );
    
    my @r = $plugin->relations();
    $container = $www->add( @r );
    $container->type( 'Relations' );
    $container->class( 'Relations' );
    
    $www->display( title => "Yggdrasil", style => "yggdrasil.css" );

} elsif( $mode eq "entity" ) {
    my @i = $plugin->instances($ident);
    my $container = $www->add( @i );
    $container->type( 'Entity' );
    $container->class( 'Entity' );
    $container->parent( $ident );

    $www->display( title => "Instance of $ident", style => "yggdrasil.css" );

} elsif( $mode eq "relation" ) {

} elsif( $mode eq "instance" ) {
    my @p = $plugin->instance( $entity, $ident );
#    use Data::Dumper;
#    print Dumper \@p;

    my $container = $www->add( @p );
    $container->type( 'Instance' );
    $container->class( 'Instance' );
    my $title = "${entity}::$ident";
    $container->parent( $title );


    my @r = $plugin->related( $entity, $ident );
    $container = $www->add(@r );
    $container->type( 'Related' );
    $container->class( 'Related' );
    $container->parent( "Relations" );


    $www->display( title => $title, style => "yggdrasil.css", script => 'yggdrasil.js' );
} 






