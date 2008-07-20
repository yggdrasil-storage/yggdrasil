package Yggdrasil;

use strict;
use warnings;

use Yggdrasil::MetaEntity;
use Yggdrasil::MetaProperty;
use Yggdrasil::MetaRelation;
use Yggdrasil::MetaInheritance;

use Yggdrasil::Storage;

our $STORAGE;

sub new {
    my $class = shift;
    my $self  = bless {}, $class;

    $self->_init(@_);

    return $self;
}

sub _init {
    my $self = shift;

    if( ref $self eq __PACKAGE__ ) {
	$self->{storage} = $STORAGE = Yggdrasil::Storage->new(@_);
    } else {
	$self->{storage} = $STORAGE;
    }
}


sub bootstrap {
    define Yggdrasil::MetaEntity;
    define Yggdrasil::MetaRelation;
    define Yggdrasil::MetaProperty;
    define Yggdrasil::MetaInheritance;
}

1;
