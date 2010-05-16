package Yggdrasil::Instance;

use strict;
use warnings;

use Yggdrasil::Local::Instance;
use Yggdrasil::Remote::Instance;

use base qw/Yggdrasil::Object/;

sub create {
    my $class  = shift;
    my %params = @_;
    
    my $yggdrasil = $params{yggdrasil};
    if( $yggdrasil->is_remote() ) {
	return Yggdrasil::Remote::Instance->create( @_ );
    } else {
	return Yggdrasil::Local::Instance->create( @_ );	
    }
}

sub fetch {
    my $class  = shift;
    my %params = @_;
    
    my $yggdrasil = $params{yggdrasil};
    if( $yggdrasil->is_remote() ) {
	return Yggdrasil::Remote::Instance->fetch( @_ );
    } else {
	return Yggdrasil::Local::Instance->fetch( @_ );	
    }
}

sub get_all {
    my $class  = shift;
    my %params = @_;
    
    my $yggdrasil = $params{yggdrasil};
    if( $yggdrasil->is_remote() ) {
	return Yggdrasil::Remote::Instance->get_all( @_ );
    } else {
	return Yggdrasil::Local::Instance->get_all( @_ );	
    }
}

1;


