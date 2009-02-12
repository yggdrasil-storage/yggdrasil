package Yggdrasil::Common::Config;

use strict;
use warnings;

use File::Spec;

# Read and parse yggdrasil configuration files.
# 1. Read global configuration files
# 2. Override values by reading user configuration files

our $ROOT_DIR = File::Spec->rootdir();
our $CFG_DIR  = 'yggdrasil';

our $GLOBAL  = File::Spec->catdir( $ROOT_DIR, 'etc', $CFG_DIR );
our $LOCAL   = File::Spec->catdir( ($ENV{HOME} || (getpwuid($>))[7]), 
				   '.'.$CFG_DIR );

sub new {
    my $class = shift;
    my $self  = {};
    
    bless $self, $class;
    $self->_init();

    return $self;
}

sub labels {
    my $self = shift;

    return keys %$self;
}

sub get {
    my $self  = shift;
    my $label = shift;

    return $self->{$label};
}

sub _init {
    my $self = shift;

    # --- Parse global config first, then user defined
    foreach my $path ( $GLOBAL, $LOCAL ) {
	$self->_parse_all_configuration( $path );
    }
}

sub _parse_all_configuration {
    my $self = shift;
    my $path = shift;

    # --- The path has to exists, be a directory, and be readable
    return unless -e $path && -d $path && -r $path;

    # --- Find all configuration files within - filter backup files
    opendir( my $dh, $path ) || return;
    my @files = grep { ! m<^\.\.?$> && ! m<(~|\.bak)$> } readdir $dh;
    closedir $dh;

    # --- Parse each configuration file
    foreach my $file ( @files ) {
	my $config = $self->_parse( File::Spec->catfile($path, $file) );

	# --- file == label
	$self->{$file} = $config;
    }
}

sub _parse {
    my $self  = shift;
    my $fqp   = shift;

    # --- The file has to be a file and be readable
    return unless -f $fqp && -r $fqp;

    # --- Open and parse
    my $config = Yggdrasil::Common::Config::Instance->new();
    $config->set( config => $fqp );

    open( my $fh, "<", $fqp ) || return;
    while( my $line = <$fh> ) {
	chomp $line;
	$line =~ s<\#.*><>;
	next unless $line =~ m<\S>;
	
	my( $key, $value ) = split m/\s*:\s*/, $line, 2;
	unless( defined $key && length $key
		&& defined $value && length $value ) {
	    # --- XXX: FIX: should log through something proper
	    print "Invalid syntax at $fqp:$. -- Ignoring line.";
	    next;
	}
	$config->set( $key => $value );
    }
    close $fqp;

    return $config;
}

package Yggdrasil::Common::Config::Instance;

use strict;
use warnings;

sub new {
    my $class = shift;
    my $self  = {};

    return bless $self, $class;
}

sub set {
    my $self  = shift;
    my $key   = shift;
    my $value = shift;

    $self->{lc $key} = $value;
}

sub get {
    my $self = shift;
    my $key  = shift;

    return $self->{lc $key};
}

sub keys :method {
    my $self = shift;

    return keys %$self;
}

1;
