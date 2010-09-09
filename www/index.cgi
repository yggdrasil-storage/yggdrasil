#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib qq($Bin/../lib);

use Yggdrasil;
use Yggdrasil::User;
use Yggdrasil::Role;
use Yggdrasil::Interface::WWW;

my $y   = Yggdrasil->new();
my $www = Yggdrasil::Interface::WWW->new( yggdrasil => $y );

my $user = $www->param('user');
my $pass = $www->param('pass');
my $sess = $www->cookie('sessionID');

my $version = Yggdrasil->version();

my $yhost = 'db.math.uio.no';
$y->connect( user     => "yggdrasil", 
	     password => "beY6KAAVNbhPa6SP",

	     host   => $yhost,
	     db     => "yggdrasil",
	     engine => "mysql",
	   );


my $u = $y->login( username => $user, password => $pass, session => $sess );
unless( $u ) {
    $www->present_login( title => "Login", info => "(version $version / yggdrasil\@$yhost)" );
    exit;
}

$u = $y->get_user( $u );
$www->{userobj} = $u;
$www->set_session( $u->session() );

# Menu module.  Presents Ygg as a dynamic tree.  Defaults to
# horizontal view.
my $menu = Yggdrasil::Interface::WWW::Module::Menu->new(
							www => $www,
						       );


# Search module.
my $search = Yggdrasil::Interface::WWW::Module::Search->new(
							    www => $www,
							   );

# The entity module displays an entity.
my $entity = Yggdrasil::Interface::WWW::Module::Entity->new(
							    www => $www,
							   );

# The instance module displays a single instance.
my $instance = Yggdrasil::Interface::WWW::Module::Instance->new(
								www => $www,
							       );

$www->start( title => "Yggweb / " . $u->id() );
$menu->display();
$search->display();
$entity->display();
$instance->display();

$www->end();
