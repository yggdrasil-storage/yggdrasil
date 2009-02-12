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

sub admin_dump {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    return $self->_admin_dump(@_);
}

sub admin_restore {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    return $self->_admin_restore(@_);
}

sub admin_define {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);

    return $self->_admin_define(@_);
}

sub _define { Yggdrasil::fatal( "_define not declared for class " . shift() . "\n" )}
sub _fetch    { Yggdrasil::fatal( "_fetch not declared for class " . shift() . "\n" )}
sub _admin_dump { Yggdrasil::fatal( "_admin_dump not declared for class " . shift() . "\n" )}
sub _admin_restore { Yggdrasil::fatal( "_admin_restore not declared for class " . shift() . "\n" )}
sub _admin_define { Yggdrasil::fatal( "_admin_define not declared for class " . shift() . "\n" )}


1;
