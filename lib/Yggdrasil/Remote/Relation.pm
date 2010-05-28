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

    my $rel = $self->storage()->{protocol}->get_relation( $params{label} );
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

    return Yggdrasil::Object::objectify(
					$self->yggdrasil(),
					__PACKAGE__,
					$self->storage()->{protocol}->get_all_relations(),
				       );
}

sub participants {
    my $self = shift;
    my $me = $self->label();

    my @ret;
    for my $set ($self->storage()->{protocol}->relation_participants( $me )) {
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

  my $label = $self->{label};

  return Yggdrasil::Object::objectify(
				      $self->yggdrasil(),
				      __PACKAGE__,
				      $self->storage()->{protocol}->relation_bind( $label,
										   $lval->_userland_id(), $rval->_userland_id() ),
				     );
}

1;
