package Yggdrasil;

use strict;
use warnings;

use Yggdrasil::MetaEntity;
use Yggdrasil::MetaProperty;
use Yggdrasil::MetaRelation;
use Yggdrasil::MetaInheritance;

use Yggdrasil::Storage;

our $STORAGE;
our $NAMESPACE;

sub new {
    my $class = shift;
    my $self  = bless {}, $class;

    $self->_init(@_);

    return $self;
}

sub _init {
    my $self = shift;
    
    if( ref $self eq __PACKAGE__ ) {
	my %params = @_;
	$NAMESPACE = $params->{namespace} || '';
	$self->{storage} = $STORAGE = Yggdrasil::Storage->new(@_);
    } else {
	$self->{storage} = $STORAGE;
	$self->{namespace} = $NAMESPACE;
    }
}


sub bootstrap {
    define Yggdrasil::MetaEntity;
    define Yggdrasil::MetaRelation;
    define Yggdrasil::MetaProperty;
    define Yggdrasil::MetaInheritance;
}

1;
