package Yggdrasil::Property;

use strict;
use warnings;

use Yggdrasil::Local::Property;
use Yggdrasil::Remote::Property;

use base qw/Yggdrasil::Object/;

sub define {
    my $class  = shift;
    my %params = @_;

    my $yggdrasil = $params{yggdrasil};
    if( $yggdrasil->is_remote() ) {
	return Yggdrasil::Remote::Property->define( @_ );
    } else {
	return Yggdrasil::Local::Property->define( @_ );
    }
}

sub get {
    my $class  = shift;
    my %params = @_;

    my $yggdrasil = $params{yggdrasil};
    if( $yggdrasil->is_remote() ) {
	return Yggdrasil::Remote::Property->get( @_ );
    } else {
	return Yggdrasil::Local::Property->get( @_ );
    }
}

sub get_all {
    my $class  = shift;
    my %params = @_;

    my $yggdrasil = $params{yggdrasil};
    if( $yggdrasil->is_remote() ) {
	return Yggdrasil::Remote::Property->get_all( @_ );
    } else {
	return Yggdrasil::Local::Property->get_all( @_ );
    }
}

sub expire {
    my $class  = shift;
    my %params = @_;

    my $yggdrasil = $params{yggdrasil};
    if( $yggdrasil->is_remote() ) {
	return Yggdrasil::Remote::Property->get_all( @_ );
    } else {
	return Yggdrasil::Local::Property->get_all( @_ );
    }
}


1;
