package Storage::Debug;

use Time::HiRes qw(gettimeofday tv_interval);

our %KEYS = (
	     transaction => 1,
	     protocol    => 1,
	     stderr      => 1,
	     verbose     => 1,
	     cache       => 1,
	    );

our $DEBUGGER;

sub new {
    my $class = shift;
    return $DEBUGGER  if $DEBUGGER;

    $self = {
	     transaction => 0,
	     protocol    => 0,
	     stderr      => 1,
	     verbose     => 0,
	     cache       => 0,
	    };
    
    bless $self, $class;
    $DEBUGGER = $self;
    return $self;
}

sub _start {
    my $self = shift;
    my $key  = shift;

    return if $self->{$key};
    $self->{active}->{$key}->{start} = [gettimeofday];
}

sub _stop {
    my $self = shift;
    my $key  = shift;

    return unless $self->{$key};

    if ($self->get( 'verbose' )) {
	my $elapsed = tv_interval([gettimeofday], $self->{active}->{$key}->{start});
	$elapsed *= -1 if $elapsed < 0;
	
	printf STDERR "Runtime was %.5f seconds\n", $elapsed;
	
	for my $k (sort keys %{$self->{active}->{$key}}) {
	    next if $k eq 'start';
	    printf STDERR "%-20s: %d\n", ucfirst $k, $self->{active}->{$key}->{$k};
	}
    }

    delete $self->{active}->{$key}; 
}

sub accepted_keys {
    return keys %KEYS;
}
 
sub get {
    my $self = shift;
    my $key  = lc shift;

    if ($KEYS{$key}) {
	return $self->{$key};
    } else {
	$self->say( "No debug key '$key'" );
	return;
    }
}

sub set {
    my $self = shift;
    my ($key, $value) = (lc shift, shift);

    if ($KEYS{$key}) {
	if ($value) {
	    $self->_start( $key );
	} else {
	    $self->_stop( $key );
	}
	$self->{$key} = $value;
	return $value;
    } else {
	$self->say( "No debug key '$key'" );
	return;
    }
}

sub activity {
    my $self = shift;
    my ($debugger, $mode) = @_;

    if ($self->{active}->{$debugger}->{$mode}) {
	$self->{active}->{$debugger}->{$mode}++;
    } else {
	$self->{active}->{$debugger}->{$mode} = 1;
    }
}

sub debug {
    my $self = shift;
    my $required_key = shift;
    my $message = join "", @_;

    return unless $self->get( $required_key );

    my $state = $self->get( 'stderr' );
    if ($state) {
	if ($state eq '1' || lc $state eq 'on') {
	    $self->say( $message );
	}
    } else {
	return $message;
    }
}

sub say {
    my $self = shift;
    my $message = shift;
    
    print STDERR "$message\n";
}

# In case the user forgets to end the debugs, end the debugging.
# If we're in verbose mode, this'll print out some extra information
# before the application exits.
sub DESTROY {
    my $self = shift;
 
    for my $k (sort keys %KEYS) {
	next if $k eq 'verbose' || $k eq 'stderr';
	$self->set( $k, 0 );
    }
}
1;
