package Yggdrasil::Storage::Mapper;

use warnings;
use strict;

use Carp;

sub new {
    my $class = shift;
    my $mappername = shift;

    # Throw-away object to access class methods
    my $self = {};
    bless $self, $class; 
    
    confess "Bad mapper '$mappername' requested" unless $self->_valid_mapper( $mappername );
    
    my $mapper_class = join("::", __PACKAGE__, $mappername );
    eval qq( require $mapper_class );
    confess $@ if $@;

    return $mapper_class->new();
}

sub _valid_mapper {
    my $self = shift;
    my $mappername = shift;

    my $path = join('/', $self->_mapper_path(), "$mappername.pm");

    return -r $path;
}


sub _mapper_path {
    my $self = shift;
    
    my $file = join('.', join('/', split '::', __PACKAGE__), "pm" );
    my $path = $INC{$file};
    $path =~ s/\.pm$//;
    return $path;
}


1;
