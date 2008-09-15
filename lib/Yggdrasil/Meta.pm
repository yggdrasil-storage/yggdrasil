package Yggdrasil::Meta;

use base qw(Yggdrasil);

sub define {
    my $class = shift;
    my $self  = $class->new(@_);
    
    return $self->_define(@_);
}

sub get {
    my $class = shift;
    my $self  = $class->new(@_);

    return $self->_get(@_);
}

sub admin_dump {
    my $class = shift;
    my $self  = $class->new(@_);

    return $self->_admin_dump(@_);
}

sub admin_restore {
    my $class = shift;
    my $self  = $class->new(@_);

    return $self->_admin_restore(@_);
}

sub admin_define {
    my $class = shift;
    my $self  = $class->new(@_);

    return $self->_admin_define(@_);
}

sub _define { Yggdrasil::fatal( "_define not declared for class " . shift() . "\n" )}
sub _get    { Yggdrasil::fatal( "_get not declared for class " . shift() . "\n" )}
sub _admin_dump { Yggdrasil::fatal( "_admin_dump not declared for class " . shift() . "\n" )}
sub _admin_restore { Yggdrasil::fatal( "_admin_restore not declared for class " . shift() . "\n" )}
sub _admin_define { Yggdrasil::fatal( "_admin_define not declared for class " . shift() . "\n" )}


1;
