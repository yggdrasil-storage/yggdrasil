package Yggdrasil::Meta;

use base qw(Yggdrasil);

sub define {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    return $self->_define(@_);
}

sub fetch {
    my $self = shift;
    return $self->_fetch(@_);
}

sub get {
    warn "Meta::get() is deprecated, fixme!";
    my $self = shift;
    return $self->fetch(@_);
}

sub get_status {
    my $self = shift;
    return $self->{yggdrasil}->{status};
}
  
sub _define { Yggdrasil::fatal( "_define not declared for class " . shift() . "\n" )}
sub _fetch    { Yggdrasil::fatal( "_fetch not declared for class " . shift() . "\n" )}

1;
