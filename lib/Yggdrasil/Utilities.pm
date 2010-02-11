package Yggdrasil::Utilities;

use strict;
use warnings;
use Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(get_times_from);

sub get_times_from {
    if (@_ == 1) {
	return ($_[0], $_[0]);
    } elsif (@_ == 2) {
	return ($_[0], $_[1]);
    } else {
	return ();
    }
} 


1;
