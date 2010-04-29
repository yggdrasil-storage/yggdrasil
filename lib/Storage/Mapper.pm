package Storage::Mapper;

use warnings;
use strict;

sub new {
    my $class = shift;
    my %params = @_;
    
    # Throw-away object to access class methods
    my $self = {};
    bless $self, $class; 
    my ($mappername, $status) = ($params{mapper}, $params{status});
    
    unless ($self->_valid_mapper( $mappername )) {
	$status->set( 500, "Bad mapper '$mappername' requested" );
	return undef;
    }
    
    my $mapper_class = join("::", __PACKAGE__, $mappername );
    eval qq( require $mapper_class );

    if ( $@ ) {
	$status->set( 500, $@ );
	return undef;
    }

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
