package Yggdrasil::Remote::Relation;

use strict;
use warnings;

use base qw(Yggdrasil::Relation);

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

sub label {
    my $self = shift;
    return $self->{label};
}

1;
