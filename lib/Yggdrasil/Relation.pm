package Yggdrasil::Relation;

use strict;
use warnings;

use Yggdrasil::Local::Relation;
use Yggdrasil::Remote::Relation;

use base qw/Yggdrasil::Object/;

sub define {
    my $class  = shift;
    my %params = @_;
    
    my $yggdrasil = $params{yggdrasil};
    if( $yggdrasil->is_remote() ) {
	return Yggdrasil::Remote::Relation->define( @_ );
    } else {
	return Yggdrasil::Local::Relation->define( @_ );	
    }
}

sub get {
    my $class  = shift;
    my %params = @_;
    
    my $yggdrasil = $params{yggdrasil};
    if( $yggdrasil->is_remote() ) {
	return Yggdrasil::Remote::Relation->get( @_ );
    } else {
	return Yggdrasil::Local::Relation->get( @_ );	
    }
}

sub get_all {
   my $class  = shift;
   my %params = @_;
   
   my $yggdrasil = $params{yggdrasil};
   if( $yggdrasil->is_remote() ) {
	return sort { $a->label() cmp $b->label() } Yggdrasil::Remote::Relation->get_all( @_ );
    } else {
	return sort { $a->label() cmp $b->label() } Yggdrasil::Local::Relation->get_all( @_ );	
    }
}

1;
