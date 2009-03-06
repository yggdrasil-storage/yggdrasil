package Yggdrasil::Debug;

use strict;
use warnings;

use Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(debug_level debug_if);  

our $debug ||= __PACKAGE__->new();

sub new {
    my ($class, $level) = @_;
    $level ||= 0;
    
    my $self = bless {}, $class;
    $self->{debug} = $level;
    $debug = $self;
    return $self;
}

sub set_debug_level {
    my $level = shift;
    
    $debug->{debug} = $level;
}

# Debug request.  Return true if the debug setting is greater than or
# equal to the given number.
sub debug_level {
    my $level = shift;

    return $level >= $debug->{debug};
}

# Debug output. Print all the parameters after the first, joined
# together, if the debug setting is greater than or equal to the
# number given as the first parameter.
sub debug_if {
    my $level = shift;
    
    if ($debug->{debug} >= $level) {
	print join( " ", @_ ), "\n";
    }
}

1;
