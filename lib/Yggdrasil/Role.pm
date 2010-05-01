package Yggdrasil::Role;

use strict;
use warnings;

use Yggdrasil::Local::Role;
use Yggdrasil::Remote::Role;

use base qw/Yggdrasil::Object/;

sub define {
    my $class  = shift;
    my %params = @_;
    
    my $yggdrasil = $params{yggdrasil};
    if( $yggdrasil->is_remote() ) {
	return Yggdrasil::Remote::Role->define( @_ );
    } else {
	return Yggdrasil::Local::Role->define( @_ );	
    }
}

sub get {
    my $class  = shift;
    my %params = @_;
    
    my $yggdrasil = $params{yggdrasil};
    if( $yggdrasil->is_remote() ) {
	return Yggdrasil::Remote::Role->get( @_ );
    } else {
	return Yggdrasil::Local::Role->get( @_ );	
    }
}

sub get_all {
    my $class  = shift;
    my %params = @_;
    
    my $yggdrasil = $params{yggdrasil};
    if( $yggdrasil->is_remote() ) {
	return Yggdrasil::Remote::Role->get_all( @_ );
    } else {
	return Yggdrasil::Local::Role->get_all( @_ );	
    }
}

1;
