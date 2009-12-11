#!/usr/bin/perl

use strict;
use warnings;

use FindBin qw($Bin);
use lib qq($Bin/../../lib);

use Yggdrasil;
use CGI::Pretty qw/-debug/;

use JSON;

my $json = JSON->new( pretty => 1 );
my $cgi = CGI::Pretty->new();

print "Content-Type: application/json\n\n";

my $y = Yggdrasil->new();
$y->connect( user     => "yggdrasil", 
	     password => "beY6KAAVNbhPa6SP",

	     host   => "db.math.uio.no",
	     db     => "yggdrasil",
	     engine => "mysql",
    );

my $sess = $cgi->cookie( "sessionID" );
my $u = $y->login( user => undef, password => undef, session => $sess );
unless( $u ) {
    my $error = { error => "I no like your session" };
    print $json->objToJson($error);
    exit;

}

my $result = { happy => "happy, happy",
	       joy   => "joy, joy" };
print $json->objToJson($result);
