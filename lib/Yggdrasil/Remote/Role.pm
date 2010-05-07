package Yggdrasil::Remote::Role;

use strict;
use warnings;

use base qw/Yggdrasil::Role/;

sub get_all {
    my $class = shift;
    my $self  = $class->SUPER::new( @_ );
    my %params = @_;

    return Yggdrasil::Object::objectify(
					$self->yggdrasil(),
					__PACKAGE__,
					$self->storage()->{protocol}->get_all_roles(),
				       );
}

sub rolename {
    my $self = shift;
    return $self->{name};
}

1;
