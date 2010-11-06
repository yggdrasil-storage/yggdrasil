package Yggdrasil::Local::Relation;

use strict;
use warnings;

use base qw/Yggdrasil::Relation/;

sub define {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %param   = @_;

    my ($lval, $rval) = @{$param{entities}};
  
    my $storage = $self->{yggdrasil}->{storage};
    
    $lval = $lval->{name} if $lval->{name};
    $rval = $rval->{name} if $rval->{name};
    
    my $label = defined $param{label} ? $param{label} : "$lval<->$rval";
    $self->{label} = $label;
    
    $lval = Yggdrasil::Local::Entity->get( yggdrasil => $self, entity => $lval );
    $rval = Yggdrasil::Local::Entity->get( yggdrasil => $self, entity => $rval );

    $self->{lval} = $lval;
    $self->{rval} = $rval;

    # --- Add to MetaRelation
    my $id = Yggdrasil::MetaRelation->add( yggdrasil => $self, 
					   lval      => $lval->_internal_id(),
					   rval      => $rval->_internal_id(),
					   label     => $label);

    return __PACKAGE__->get( yggdrasil => $self, label => $label );
}

sub get {
    my $class  = shift;
    my $self   = $class->SUPER::new(@_);
    my %params = @_; 
    
    my $time = $params{time} || {};

    my $status = $params{yggdrasil}->get_status();
    my $ref = $self->storage()->fetch( "MetaRelation" => { return => [qw/id label lval rval start stop/],
							   where  => [ 'label' => $params{label} ] },
				       $time
				     );

    if( $ref && defined $ref->[0]->{id} ) {
	$status->set( 200 );
	return objectify(
			 label     => $ref->[0]->{label},
			 id        => $ref->[0]->{id},
			 realstart => $ref->[0]->{start},
			 realstop  => $ref->[0]->{stop},
			 start     => $time->{start} || $ref->[0]->{start},
			 stop      => $time->{stop} || $ref->[0]->{stop},
			 lval      => Yggdrasil::Local::Entity->get( yggdrasil => $self, id => $ref->[0]->{lval} ),
			 rval      => Yggdrasil::Local::Entity->get( yggdrasil => $self, id => $ref->[0]->{rval} ),
			 yggdrasil => $self->{yggdrasil},
			);
    } else {
	$status->set( 404 );
	return undef;	
    }    
}

sub expire {
    my $self = shift;

    # Do not expire historic Relations
    if( $self->stop() ) {
	$self->get_status()->set( 406, "Unable to expire historic relation" );
	return 0;
    }

    my $storage = $self->storage();
    $storage->expire( 'Relations', relationid => $self->_internal_id() );
    $storage->expire( 'MetaRelation', id => $self->_internal_id() );
}

sub objectify {
    my %params = @_;
    
    my $obj = new Yggdrasil::Local::Relation( label => $params{label}, yggdrasil => $params{yggdrasil} );
    $obj->{_id}        = $params{id};
    $obj->{_start}     = $params{start};
    $obj->{_stop}      = $params{stop};
    $obj->{_realstart} = $params{realstart};
    $obj->{_realstop}  = $params{realstop};
    $obj->{lval}       = $params{lval};
    $obj->{rval}       = $params{rval};
    $obj->{label}      = $params{label};
    return $obj;
}

sub get_all {
    my $class  = shift;
    my $self   = $class->SUPER::new(@_);
    my %params = @_;

    my $time = $self->_validate_temporal( $params{time} );
    return unless $time;

    my $aref = $self->storage()->fetch( 'MetaRelation', { return => [ 'id', 'start', 'stop', 'rval', 'lval', 'label' ] },
				      $time );

    return map { objectify( label     => $_->{label},
			    id        => $_->{id},
			    start     => $time->{start} || $_->{start},
			    stop      => $time->{stop} || $_->{stop},
			    realstart => $_->{start},
			    realstop  => $_->{stop},
			    lval      => Yggdrasil::Local::Entity->get( yggdrasil => $self, id => $_->{lval} ),
			    rval      => Yggdrasil::Local::Entity->get( yggdrasil => $self, id => $_->{rval} ),
			    yggdrasil => $self->{yggdrasil},
			  ) } @$aref;
    
}

sub _get_real_val {
    my $self  = shift;
    my $side  = shift;
    my $label = shift;

    my $retref = $self->storage()->fetch( 'MetaEntity', { return => 'entity',
							  where  => [ id => \qq<MetaRelation.$side> ]},
					  'MetaRelation', { where => [ label => $label ]});
    return $retref->[0]->{entity};
}

sub participants {
    my $self = shift;
    my %params = @_;

    my $storage = $self->storage();

    my $time = $self->_validate_temporal( $params{time} );
    return unless $time;
    
    my $le = $self->{lval};
    my $re = $self->{rval};

    my $parts = $storage->fetch(
				Relations => {
					      return => ['relationid', 'lval', 'rval'],
					      where  => [ relationid => $self->_internal_id() ] },
				$time
			       );

    # FIX: li and ri should be real Instance objects
    my @participants;
    foreach my $part (@$parts) {
	my $l = $part->{lval};
	my $r = $part->{rval};
	my $lval = $storage->fetch( Instances => { where => [ id => $l ],
						  return => 'visual_id' }, 
				    $time );
	my $rval = $storage->fetch( Instances => { where => [ id => $r ],
						  return => 'visual_id' },
				    $time );
	
	my $li = Yggdrasil::Local::Instance->new( yggdrasil => $self );
	$li->{visual_id} = $lval->[0]->{visual_id};
	$li->{_id}       = $l;
	$li->{entity}    = $le;

	my $ri = Yggdrasil::Local::Instance->new( yggdrasil => $self );
	$ri->{visual_id} = $rval->[0]->{visual_id};
	$ri->{_id}       = $r;
	$ri->{entity}    = $re;

	push( @participants, [ $li, $ri ] );
    }

    return @participants;
}

sub link :method {
  my $self = shift;
  my $lval = shift;
  my $rval = shift;

  return unless $self->_validate_link_objects( $lval, $rval );

  $self->storage()->store( 'Relations',
			   key => ['relationid', 'lval', 'rval' ],
			   fields => {
			       'relationid' => $self->_internal_id(),
			       'lval' => $lval->_internal_id(),
			       'rval' => $rval->_internal_id() });
}

sub unlink :method {
  my $self = shift;
  my $lval = shift;
  my $rval = shift;

  $self->storage()->expire( 'Relations', lval => $lval->_internal_id(), rval => $rval->_internal_id() );
}

1;
