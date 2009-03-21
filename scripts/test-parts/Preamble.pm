package Preamble;

use strict;
use warnings;

use Getopt::Long;

use FindBin qw($Bin);
use lib qq($Bin/../../lib);

use vars qw|@ISA @EXPORT_OK|;

require Exporter;
@ISA = qw|Exporter|;
@EXPORT_OK = qw|getopts status status_die|;
  
use Yggdrasil;

my $status;

my ($user, $password, $host, $port,
    $db, $engine, $mapper, $yuser, $ypass, $debug) =
  ($ENV{YGG_USER}, $ENV{YGG_PASSWORD}, $ENV{YGG_HOST}, $ENV{YGG_PORT}, 
   $ENV{YGG_DB}, $ENV{YGG_ENGINE}, undef, undef, undef, undef);

sub getopts {
    my %opts;
    
    GetOptions(
	       "user=s"       => \$user,
	       "engine=s"     => \$engine,
	       "debug:i"      => \$debug,
	       "password=s"   => \$password,
	       "host=s"       => \$host,
	       "database=s"   => \$db,
	       "engine=s"     => \$engine,
	       "port=s"       => \$port,
	       "mapper=s"     => \$mapper,
	       "yuser=s"      => \$yuser,
	       "ypass=s"      => \$ypass,
	      );


#    print "$user\@$host ($db / $engine)\n";
    
    return { user => $user, engine => $engine, password => $password, host => $host,
	     db => $db, port => $port, mapper => $mapper,
	     yuser => $yuser, ypass => $ypass,
	     debug => $debug,
	   };
    
}

sub status {
    my $msg = shift;
    my $var = shift;
    my $die_on_not_ok = shift;

    if (ref $var eq 'Yggdrasil') {
	$status = $var->{status};
    } elsif (! $status) {
	print "Yggdrasil not checked first";
	return;
    }
    
    $var = 'undefined!' unless defined $var;
    
    print "$msg: ", 
      join ", ", $status->OK()?"OK":"NOT OK",
	$status->status(), $status->english(), "<" . $status->message() . "> ($var)\n";

    if (! $status->OK() && $die_on_not_ok) {
	print "*** Check(s) failed, exiting upon request.\n";
	exit 1;
    }
    
}

sub status_die {
    status( @_, 1 );
}
