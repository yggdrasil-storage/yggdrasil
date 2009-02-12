package Yggdrasil::Common::CommandLine;

use strict;
use warnings;

use Getopt::Long;

my $r = GetOptions( 'help'        => \&help,
		    'version'     => \&version,
		    'verbose:i'   => sub { set( verbose => @_ ) },
		    'list-labels' => sub { 'Hmmm ...' },
		    
		    'label=s'     => sub { set( label => @_ ) },
		    "host=s"      => sub { set( host  => @_ ) },
		    'port=i'      => sub { set( port  => @_ ) },
		    );


sub set {
    my $key = shift;
    my $val = shift;

    our %ARGS = ();

    if( $key eq "verbose" && ! defined $val ) {
	$ARGS{$key}++;
    } else {
	$ARGS{$key} = $val;
    }
}


sub help {
    # call callers help()
    print <DATA>;

    exit;
}

sub version {
    # print callers $VERSION

    exit;
}

1;

__DATA__

Other Options:
--------------
--help             Prints out usage.
--version          Prints version information.
--verbose [level]  Sets or increases verbosity level.
--list-labels      Lists all defined labels.
--label <name>     Specify label of configuration.
--host <host>      Specify yggdrasil host.
--port <port>      Specify yggdrasil port.
