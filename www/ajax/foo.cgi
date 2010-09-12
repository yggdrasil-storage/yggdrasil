#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib qq($Bin/../../lib);

use Yggdrasil;
use Yggdrasil::Common::Config;
use CGI::Pretty qw/-debug/;

use JSON;

my $json = JSON->new();
my $cgi = CGI::Pretty->new();

print "Content-Type: application/json\n\n";

my $c = Yggdrasil::Common::Config->new();
my $y = Yggdrasil->new();

my $config = $c->get( 'web' );
die "Unable to load the web configuration" unless $config;

my $yhost  = $config->get( 'enginehost' );

$y->connect( user     => $config->get( 'engineuser' ),
	     password => $config->get( 'enginepassword' ),

	     host   => $yhost,
	     db     => $config->get( 'enginedb' ),
	     engine => $config->get( 'enginetype' ),
	   );

my $sess = $cgi->cookie( "sessionID" );
my $u = $y->login( user => undef, password => undef, session => $sess );
unless( $u ) {
    &error( 'I no like your session' );
    exit;

}

my $mode  = $cgi->param( 'mode' ) || '';
my $start = $cgi->param( 'start' ) || '';
my $stop  = $cgi->param( 'stop' ) || '';

my $entity   = $cgi->param( 'entity' ) || '';
my $instance = $cgi->param( 'instance' ) || '';
my $property = $cgi->param( 'property' ) || '';

if ($mode eq 'entities') {
    exec_entities();
} elsif ($mode eq 'relations') {
    exec_relations( $cgi->param( 'entity' ));
} elsif ($entity) {
    exec_entity( $entity );
} elsif ($instance) {
    exec_instance( $entity, $instance );
} elsif ($property) {
    exec_property( $entity, $property );
} else {
    error( 'Unknown query' );
}



sub exec_entities {
    my @data = map { nameify( $_ ) } $y->entities();
    print $json->encode( \@data );
}
  
sub exec_relations {
    my $entity = shift;

    if ($entity) {
	&error( 'Getting relations for a specific entity is not supported' ); 
    } else {
	my @data = map { nameify( $_ ) } $y->relations();
	print $json->encode( \@data );	
    }
}
  
sub exec_entity {
    my $entity = shift;
    
    my $eobj = $y->get_entity( $entity );
    
    unless ($eobj) {
	&error( $y->get_status()->message() );
	return;
    }

    my @i = map { nameify( $_ ) } $eobj->instances();
    my @p = map { nameify( $_ ) } $eobj->properties();
    
    print $json->encode( [ \@i, \@p ] );
}

sub exec_instance {
    &error( 'Not implemented' );
}
  
sub exec_property {
    &error( 'Not implemented' );
}
  
sub error {
    my $string = shift;
    print $json->encode( { error => $string } );
}


sub nameify {
    my $obj = shift;
    
    if ($obj->stop()) {
        return $obj->id() . ':' . $obj->start() . '-' . $obj->stop();
    } else {
        return $obj->id();
    }
}

