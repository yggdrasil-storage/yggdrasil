#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib qq($Bin/../lib);

use Yggdrasil;
use Yggdrasil::User;
use Yggdrasil::Role;
use Yggdrasil::Interface::WWW;
use Yggdrasil::Common::Config;

my $y   = Yggdrasil->new();
my $www = Yggdrasil::Interface::WWW->new( yggdrasil => $y );

my $user = $www->param('user');
my $pass = $www->param('pass');
my $sess = $www->cookie('sessionID');
my $mode = $www->param( 'mode' ) || '';

my $version = Yggdrasil->version();

my $c = Yggdrasil::Common::Config->new();
my $config = $c->get( 'web' );
die "Unable to load the web configuration" unless $config;

my $yhost  = $config->get( 'enginehost' );

$y->connect( user     => $config->get( 'engineuser' ),
	     password => $config->get( 'enginepassword' ),

	     host   => $yhost,
	     db     => $config->get( 'enginedb' ),
	     engine => $config->get( 'enginetype' ),
	   );

my $u = $y->login( username => $user, password => $pass, session => $sess );
$u = $y->get_user( $u );

if ($mode eq 'logout') {
    $u->session( '' );
    print $www->{cgi}->redirect( $www->{cgi}->url() );
    exit;
}

unless ($u) {
    $www->present_login( title => "Login", info => "(version $version / yggdrasil\@$yhost)" );
    exit;
}

$www->{userobj} = $u;
$www->set_session( $u->session() );


# The binary module must be able to set its own headers and stuff.
if ($mode eq 'binary') {
    my $bin = Yggdrasil::Interface::WWW::Module::Binary->new( www => $www );
    $bin->display();
    exit;
}

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

print "<div id='content'>\n";

$search->display();
$entity->display();
$instance->display();

if ($mode eq 'about') {
    my $about = Yggdrasil::Interface::WWW::Module::About->new( www => $www );
    $about->display();
} elsif ($mode eq 'user') {
    my $uinfo = Yggdrasil::Interface::WWW::Module::User->new( www => $www );
    $uinfo->display();
}

# Close "container", then "content".
print "</div>\n";

$www->end();
