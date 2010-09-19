package Yggdrasil::Remote::Relation;

use strict;
use warnings;

use base qw(Yggdrasil::Relation);

# FIXME: Constraints and such.
sub define {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;
    my ($lval, $rval) = @{$params{entities}};

    return Yggdrasil::Object::objectify(
					$self->yggdrasil(),
					__PACKAGE__,
					$self->storage()->{protocol}->define_relation( $params{label},
										       $lval->_userland_id(), $rval->_userland_id() ),
				       );
    
}

sub get {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    my %params = @_;
    my $time = $self->_validate_temporal( $params{time} ); 
    return unless $time;
    
    my $rel = $self->storage()->{protocol}->get_relation( $params{label}, $time );
    return unless $rel;
    
    $rel->{lval} = $self->yggdrasil()->get_entity( $rel->{lval} );
    return unless $rel->{lval};
    $rel->{rval} = $self->yggdrasil()->get_entity( $rel->{rval} );
    return unless $rel->{rval};
    
    return Yggdrasil::Object::objectify(					
					$self->yggdrasil(),
					__PACKAGE__,
					$rel,
				       );
}

sub get_all {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    my %params = @_;
    my $time = $self->_validate_temporal( $params{time} ); 
    return unless $time;

    return Yggdrasil::Object::objectify(
					$self->yggdrasil(),
					__PACKAGE__,
					$self->storage()->{protocol}->get_all_relations( $time ),
				       );
}

sub participants {
    my $self = shift;
    my $me = $self->_userland_id();

    my %params = @_;
    my $time = $self->_validate_temporal( $params{time} ); 
    return unless $time;

    my @ret;
    for my $set ($self->storage()->{protocol}->relation_participants( $me, $time )) {
	my ($elval, $erval) = $self->entities();
	my $lval = $self->yggdrasil()->get_instance( $elval, $set->{lval} );
	my $rval = $self->yggdrasil()->get_instance( $erval, $set->{rval} );
	push @ret, [ $lval, $rval ];
    }
    return @ret;    
}

sub link :method {
  my $self = shift;
  my $lval = shift;
  my $rval = shift;

  if( $self->stop() || $lval->stop() || $rval->stop()) {
      $self->get_status()->set( 406, "Unable to link in historic context" );
      return 0;
  }

  my $label = $self->{label};

  return Yggdrasil::Object::objectify(
				      $self->yggdrasil(),
				      __PACKAGE__,
				      $self->storage()->{protocol}->relation_bind( $label,
										   $lval->_userland_id(), $rval->_userland_id() ),
				     );
}

1;
