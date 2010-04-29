package Storage::Type;

use strict;
use warnings;

sub new {
    my $class = shift;

    my $self  = {
		 valid_types => {
				 TEXT      => 1,
				 VARCHAR   => 255,
				 BOOLEAN   => 1,
				 SET       => 1,
				 INTEGER   => 1,
				 FLOAT     => 1,
				 TIMESTAMP => 1,
				 DATE      => 1,
				 SERIAL    => 1,
				 BINARY    => 1,
				 PASSWORD  => 1,				  
				},
		};
    bless $self, $class;    


    my $path = join('/', $self->_filter_path(), 'Filter');
    if (opendir( my $fh, $path )) {
	for my $filter (readdir $fh) {
	    next unless $filter =~ /\.pm$/;
	    $filter =~ s/\.pm//;
	    my $filter_class = join("::", __PACKAGE__, 'Filter', $filter );
	    eval qq( require $filter_class );
	    if ($@) {
		# FIXME: scream and log this error, but do not die.
		warn $@;
	    }
	    $self->{filters}->{lc $filter} = $filter_class;
	}
    }
    
    return $self;
}

sub apply_filter {
    my $self = shift;
    my ($filter, $context, $value, @params) = @_;

    my $filter_class = $self->{filters}->{lc $filter};
    unless ($filter_class) {
	warn "No such filter, $filter\n";
	return $value;
    }
 
    # FIXME, what if the methods don't exist?    
    return $filter_class->$context( $value, @params );
}

sub valid_types {
    my $self = shift;
    return keys %{$self->{valid_types}};
}

sub is_valid_type {
    my $self = shift;
    my $type = shift;

    return $self->{valid_types}->{$type};    
}

sub _filter_path {
    my $self = shift;
    
    my $file = join('.', join('/', split '::', __PACKAGE__), "pm" );
    my $path = $INC{$file};
    $path =~ s/\.pm$//;
    return $path;
}

1;
