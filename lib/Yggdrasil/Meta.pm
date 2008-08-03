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

sub _define { die "_define not declared for class " . shift() . "\n" }
sub _get    { die "_get not declared for class " . shift() . "\n" }


1;
