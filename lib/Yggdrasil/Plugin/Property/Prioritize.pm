package Yggdrasil::Plugin::Property::Prioritize;

use strict;
use warnings;

use base qw(Yggdrasil::Plugin::Shared);


sub instance {
    my $self = shift;
    my $entity = shift;
    my $ident = shift;


    my @p = $self->SUPER::instance( $entity, $ident );
    my @v;
    foreach my $prop ( @p ) {
	# --- XXX: remove me --- test
	my $level = 5 + int(rand(10));
	if( $prop->{property} eq "position" || $prop->{property} eq "dinner" ) {
	    $level = 3;
	}

	next if $level < $self->{level};

	push( @v, $prop );
    }

    return @v;
}

sub related {
    my $self = shift;
    my $entity = shift;
    my $ident = shift;

    my @p = $self->SUPER::related( $entity, $ident );
    my @v;
    foreach my $e ( @p ) {
	next unless @{ $e->{value} };



	push( @v, $e );
    }

    return @v;
}

1;
