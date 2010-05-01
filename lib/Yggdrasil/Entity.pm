package Yggdrasil::Entity;

use strict;
use warnings;

use Yggdrasil::Local::Entity;
use Yggdrasil::Remote::Entity;

use base qw/Yggdrasil::Object/;

sub define {
    my $class = shift;
    my %params = @_;

    my $yggdrasil = $params{yggdrasil};
    if( $yggdrasil->is_remote() ) {
	return Yggdrasil::Remote::Entity->define( @_ );
    } else {
	return Yggdrasil::Local::Entity->define( @_ );
    }
}

sub get {
    my $class = shift;
    my %params = @_;

    my $yggdrasil = $params{yggdrasil};
    if( $yggdrasil->is_remote() ) {
	return Yggdrasil::Remote::Entity->get( @_ );
    } else {
	return Yggdrasil::Local::Entity->get( @_ );
    }
}

sub get_all {
    my $class = shift;
    my %params = @_;

    my $yggdrasil = $params{yggdrasil};
    if( $yggdrasil->is_remote() ) {
	return Yggdrasil::Remote::Entity->get_all( @_ );
    } else {
	return Yggdrasil::Local::Entity->get_all( @_ );
    }
}

1;
