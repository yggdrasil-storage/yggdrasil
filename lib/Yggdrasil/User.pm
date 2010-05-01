package Yggdrasil::User;

use strict;
use warnings;

use Yggdrasil::Local::User;
use Yggdrasil::Remote::User;

use base qw/Yggdrasil::Object/;

sub define {
    my $class  = shift;
    my %params = @_;
    
    my $yggdrasil = $params{yggdrasil};
    if( $yggdrasil->is_remote() ) {
	return Yggdrasil::Remote::User->define( @_ );
    } else {
	return Yggdrasil::Local::User->define( @_ );	
    }
}


sub get {
    my $class  = shift;
    my %params = @_;
    
    my $yggdrasil = $params{yggdrasil};
    if( $yggdrasil->is_remote() ) {
	return Yggdrasil::Remote::User->get( @_ );
    } else {
	return Yggdrasil::Local::User->get( @_ );	
    }
}

sub get_all {
    my $class  = shift;
    my %params = @_;
    
    my $yggdrasil = $params{yggdrasil};
    if( $yggdrasil->is_remote() ) {
	return Yggdrasil::Remote::User->get_all( @_ );
    } else {
	return Yggdrasil::Local::User->get_all( @_ );	
    }
}

1;
