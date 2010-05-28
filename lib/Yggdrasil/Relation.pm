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
	return sort { $a->_userland_id() cmp $b->_userland_id() } Yggdrasil::Remote::Relation->get_all( @_ );
    } else {
	return sort { $a->_userland_id() cmp $b->_userland_id() } Yggdrasil::Local::Relation->get_all( @_ );	
    }
}

sub entities {
    my $self = shift;
    return ( $self->{lval}, $self->{rval} );
}

sub id {
    my $self = shift;
    return $self->{label};
}

sub _userland_id {
    my $self = shift;    
    return $self->id();
}

1;
