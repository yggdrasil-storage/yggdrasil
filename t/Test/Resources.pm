package Test::Resources;

use strict;
use warnings;

sub new {
    my $class = shift;
    my $self  = {};

    return bless $self, $class;
}

sub get_tests {
    my $self = shift;
    my $name = shift;

    my $file = $self->_path( $name );
    return unless -e $file;

    open( my $fh, $file );
    my $tests = $self->parse_tests( $fh );
    close( $fh );

    return $tests;
}

sub parse_tests {
    my $self = shift;
    my $fh   = shift;

    my %tests;

    my $data;
    {
	local $/ = undef;
	$data = <$fh>;
    }

    my $i = 0;
    my $name;
    for my $t ( split m/-- \n/, $data ) {
	if( $i % 2 == 0 ) {
	    # name
	    chomp($t);
	    $name = $t;
	} elsif( $i % 2 == 1 ) {
	    # test
	    $tests{ $name } = $t;
	}
	
	$i++;
    }

    return \%tests;
}

sub _path {
    my $self = shift;
    my $file = shift;

    my $me = join('.', join('/', split '::', __PACKAGE__), "pm" );
    my $path = $INC{$me};
    $path =~ s/\.pm$//;
  
    return join('/', $path, $file);
}

1;
