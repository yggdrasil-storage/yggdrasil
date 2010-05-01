package Yggdrasil::Utilities;

use strict;
use warnings;
use Exporter;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(get_times_from time_diff plural_p);

sub get_times_from {
    if (@_ == 1) {
	return ($_[0], $_[0]);
    } elsif (@_ == 2) {
	return ($_[0], $_[1]);
    } else {
	return ();
    }
} 

sub time_diff {
    my $stamp = shift;
    my $delta = time - $stamp;
    my @values;
    
    my $weeks = int($delta / 604800);
    if ($weeks > 0) {
        push @values, plural_p($weeks, "week");
        $delta -= $weeks * 604800;
    }
    my $days = int($delta / 86400);
    if ($days > 0) {
        push @values, plural_p($days, "day");
        $delta -= $days * 86400;
    }
    my $hours = int($delta / 3600);
    if ($hours > 0) {
        push @values, plural_p($hours, "hour");
        $delta -= $hours * 3600;
    }
    my $minutes = int($delta / 60);
    if ($minutes > 0) {
        push @values, plural_p($minutes, "minute");
        $delta -= $minutes * 60;
    }

    if ($delta) {
	push @values, plural_p($delta, "second");
    } elsif (! @values) {
	push @values, "0 seconds";
    }

    return join ", ", @values;
}

sub plural_p {
    my $value = shift;
    my $string = shift;
    
    if ($value > 1 || ! $value) {
        return "$value ${string}s";
    } else {
        return "$value $string";        
    }
}

1;
