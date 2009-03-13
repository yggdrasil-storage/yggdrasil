package Yggdrasil::Utilities;

use strict;
use warnings;

sub get_times_from {
    if (@_ == 1) {
	return ($_[0], $_[0]);
    } elsif (@_ == 2) {
	return ($_[0], $_[1]);
    } else {
	return ();
    }
} 

sub ancestors {
    my $storage = shift;
    my $entity  = shift;
    my ($start, $stop) = @_;

    $entity = $storage->get_entity_id( $entity );
    
    my @ancestors;
    my %seen = ( $entity => 1 );

    my $r = $storage->fetch( 'MetaInheritance', { return => "parent", where => [ child => $entity ] },
			     { start => $start, stop => $stop });
    
    while( @$r ) {
	my $parent = $r->[0]->{parent};
	last if $seen{$parent};
	$seen{$parent} = 1;
	push( @ancestors, $storage->get_entity_name( $parent ) );

	$r = $storage->fetch( 'MetaInheritance', { return => "parent", where => [ child => $parent ] },
			      { start => $start, stop => $stop } );
    }

    return @ancestors;
}



1;
