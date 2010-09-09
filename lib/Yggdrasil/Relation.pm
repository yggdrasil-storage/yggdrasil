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

sub can_write {
    my $self = shift;
    
    return $self->storage()->can( update => 'MetaRelation', { id => $self->_internal_id() } );
}

sub can_expire {
    my $self = shift;
    
    return $self->storage()->can( expire => 'MetaRelation', { id => $self->_internal_id() } );
}

sub can_link {
    my $self = shift;
    my $lval = shift;
    my $rval = shift;
    
    return unless $self->_validate_link_objects( $lval, $rval );
    return $self->storage()->can( create => 'Relation', { relationid => $self->_internal_id(), 
							  lval => $lval->_internal_id(),
							  rval => $rval->_internal_id() } );
}

sub can_unlink {
    my $self = shift;
    my $lval = shift;
    my $rval = shift;

    return unless $self->_validate_link_objects( $lval, $rval );
    return $self->storage()->can( expire => 'Relation', { relationid => $self->_internal_id(), 
							  lval => $lval->_internal_id(),
							  rval => $rval->_internal_id() } );
    
}

sub _validate_link_objects {
    my $self = shift;
    my $lval = shift;
    my $rval = shift;

    my $label = $self->{label};
    
    my $reallval = $self->_get_real_val( 'lval', $label );
    my $realrval = $self->_get_real_val( 'rval', $label );
    
    my $status = $self->get_status();
    unless ($lval && ref $lval && $lval->isa( 'Yggdrasil::Instance' )) {
	$status->set( 406, "The first paramter to link has to be an instance object." );
	return undef;      
    }
    
    unless ($rval && ref $rval && $rval->isa( 'Yggdrasil::Instance' )) {
	$status->set( 406, "The second paramter to link has to be an instance object." );
	return undef;      
  }
    
    unless ($lval->is_a( $reallval )) {
	$status->set( 406, $lval->id() . " cannot use the relation $label, incompatible instance / inheritance." );
	return undef;
    }
    
    unless ($rval->is_a( $realrval )) {
	$status->set( 406, $rval->id() . " cannot use the relation $label, incompatible instance / inheritance." );
	return undef;
    }

    return 1;
}

1;
