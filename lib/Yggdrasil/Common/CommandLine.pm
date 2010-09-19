package Yggdrasil::Common::CommandLine;

use strict;
use warnings;

use Getopt::Long;

use Yggdrasil::Common::Config;

our $VERSION = '0.0.1';
our $SELF = bless {}, __PACKAGE__;

sub new {
    return $SELF;
}

sub get {
    my $self = shift;
    my $key  = shift;

    return $self->{$key};
}

sub import {
    my $class = shift;
    my %args  = @_;

    my $caller = caller(0);

    # --- Store import arguments and caller, we'll be needing them later
    my $self = __PACKAGE__->new();
    $self->{_import} = \%args;
    $self->{_caller} = $caller;

    $self->_setup();
}

sub _setup {
    my $self = shift;

    Getopt::Long::Configure( "pass_through" );

    my $set = sub {
	my( $key, $val ) = @_;
	if( $key eq "verbose" && ! defined $val ) {
	    $self->{$key}++;
	} elsif ( $key eq 'list-lables' ) {
	    $self->{$key} = 1;
	} else {
	    $self->{$key} = $val;
	}
    };


    my $r = GetOptions( 'help'        => $set,
			'version'     => $set,
			'verbose:i'   => $set,
			'list-lables' => $set,
			'debug:i'     => $set, 
			'label=s'     => $set,
			'username=s'  => $set,
			'password=s'  => $set,
#			'host=s'      => $set,
#			'port=i'      => $set,
		      );

    exit -1 unless $r;
}

sub INIT {
    my $self   = __PACKAGE__->new();
    my $caller = $self->{_caller};
    my %args   = %{ $self->{_import} };

    my $version = $caller->UNIVERSAL::VERSION;
    unless( $version ) {
	die 'You must declare $VERSION in your program' . "\n";
    }

    # --- Help?
    if( defined $self->{help} ) {
	$self->help();

        exit;
    } elsif( defined $self->{version} ) {
	$self->version();
	
	exit;
    } elsif (defined $self->{'list-lables'}) {
	$self->_list_labels();
	
	exit;
    } elsif (defined $self->{username} && ! defined $self->{password} && -t) {
	# We have a user, but no password, and we have a TTY.  Let's
	# ask for a password shall we?
	$self->{password} = $self->read_password();
    }
}

sub read_password {    
    my $password;
    print "Password: ";
    system("stty -echo");
    chop($password = <STDIN>);
    print "\n";
    system("stty echo");
    return $password;
}

sub _client_help {
    no warnings 'once';
    no strict 'refs';

    my $caller = $SELF->{_caller};
    if( exists ${ $caller . '::' }{DATA} ) {
        my $fh = ${ $caller . '::' }{DATA};
        print while <$fh>;
    }
}

sub help {
    my $self = shift;

    $self->_help( "head" );
    $self->_client_help();
    $self->_help( "body" );
}

sub version {
    my $self = shift;

    my $version = $self->{_caller}->VERSION;
    print "$0 version $version\n";
}

sub _list_labels {
    my $self = shift;
    
    my $c = Yggdrasil::Common::Config->new();
    for my $l ($c->labels()) {
	print "$l:\n";
	my $lo = $c->get( $l );
	for my $k (sort $lo->keys()) {
	    printf "  %15s - %s\n", $k, $lo->get( $k );
	}
	print "\n";
    }
}

sub _help {
    my $self = shift;
    my $arg  = shift;

    my $head = "Usage: $0 [options]\n\n";

    if( $arg eq "head" ) {
        print $head;
    } elsif( $arg eq "body" ) {
        print <<HELP_BODY;
Other Options:
--------------
--help             Prints out usage.
--version          Prints version information.
--verbose [level]  Sets or increases verbosity level.
--list-lables      Lists all defined labels.
--label <name>     Specify label of configuration.
--user <name>      Username.
--password <pw>    Password.
--host <host>      Specify yggdrasil host.
--port <port>      Specify yggdrasil port.
HELP_BODY
    }
}


1;
