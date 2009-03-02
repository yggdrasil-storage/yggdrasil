package Yggdrasil::Common::CommandLine;

use strict;
use warnings;

use UNIVERSAL qw/VERSION/;
use Getopt::Long;

our $VERSION = 0.01;
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
	} else {
	    $self->{$key} = $val;
	}
    };


    my $r = GetOptions( 'help'        => $set,
			'version'     => $set,
			'verbose:i'   => $set,
			'list-labels' => $set,
			'debug:i'     => $set, 
			'label=s'     => $set,
#			'host=s'      => $set,
#			'port=i'      => $set,
		      );

    exit -1 unless $r;
}

sub INIT {
    my $self   = __PACKAGE__->new();
    my $caller = $self->{_caller};
    my %args   = %{ $self->{_import} };

    my $version = $caller->VERSION;
    unless( $version ) {
	die 'You must declare $VERSION in your program' . "\n";
    }

    # --- Help?
    if( defined $self->{help} ) {
	$self->_help( "head" );
	$self->_client_help();
        $self->_help( "body" );
        
        exit;
    } elsif( defined $self->{version} ) {
	$self->_version();
	
	exit;
    }
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


sub _version {
    my $self = shift;

    my $version = $self->{_caller}->VERSION;
    print "$0 version $version\n";
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
--list-labels      Lists all defined labels.
--label <name>     Specify label of configuration.
--host <host>      Specify yggdrasil host.
--port <port>      Specify yggdrasil port.
HELP_BODY
    }
}


1;
