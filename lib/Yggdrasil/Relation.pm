package Yggdrasil::Relation;

use strict;
use warnings;

use base qw(Yggdrasil::MetaRelation);

sub _define {
  my $self = shift;
  my $lval = Yggdrasil::_extract_entity( shift );    
  my $rval = Yggdrasil::_extract_entity( shift );
  my %param   = @_;

  my $label = $param{'label'} || "$lval<->$rval";
  $self->{label} = $label;

  $lval = $self->{storage}->fetch( 'MetaEntity', { return => 'id', where => [ entity => $lval ] } );
  $rval = $self->{storage}->fetch( 'MetaEntity', { return => 'id', where => [ entity => $rval ] } );

  $lval = $lval->[0]->{id};
  $rval = $rval->[0]->{id};
  
  unless( $param{raw} ) {
      my $id = $self->{storage}->_get_relation( $label );
      if (defined $id) {
	  $self->{_id} = $id;
	  return $self 
      }
  }

  # --- Add to MetaRelation
  my $id = $self->_meta_add($lval, $rval, $label, %param) unless $param{raw};
  $self->{_id} = $id;
  return $self;
}

sub _get_real_val {
    my $self  = shift;
    my $side  = shift;
    my $label = shift;

    my $retref = $self->{storage}->fetch( 'MetaEntity', { return => 'entity',
							  where  => [ id => \qq<MetaRelation.$side> ]},
					  'MetaRelation', { where => [ label => $label ]});
    return $retref->[0]->{entity};
}

sub link :method {
  my $self = shift;
  my $lval = shift;
  my $rval = shift;

  my $label = $self->{label};

  my $reallval = $self->_get_real_val( 'lval', $label );
  my $realrval = $self->_get_real_val( 'rval', $label );
  
  Yggdrasil::fatal( $lval->id() . " cannot use the relation $label, incompatible instance / inheritance.")
      unless $lval->isa( $reallval );

  Yggdrasil::fatal( $rval->id() . " cannot use the relation $label, incompatible instance / inheritance.")
      unless $rval->isa( $realrval );

  $self->{storage}->store( 'Relations',
			   key => ['id', 'lval', 'rval' ],
			   fields => {
				      'id'   => $self->{_id},
				      'lval' => $lval->{_id},
				      'rval' => $rval->{_id} });
}

sub unlink :method {
  my $self = shift;
  my $lval = shift;
  my $rval = shift;

  $self->{storage}->expire( 'Relations', lval => $lval->{_id}, rval => $rval->{_id} );
}


sub _admin_dump {
    my $self = shift;

    return $self->{storage}->raw_fetch( 'Relations' );
}

sub _admin_restore {
    my $self = shift;
    my $data = shift;

    $self->{storage}->raw_store( 'Relations', fields => $data );
}

sub _admin_define {
    my $self = shift;
    my $lval = shift;
    my $rval = shift;

    $self->_define( $lval, $rval, raw => 1 );
}

1;
