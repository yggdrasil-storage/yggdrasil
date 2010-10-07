package Storage::Debug;

our %KEYS = (
	     transaction => 1,
	     protocol    => 1,
	     stderr      => 1,
	    );

our $DEBUGGER;

sub new {
    my $class = shift;
    return $DEBUGGER  if $DEBUGGER;

    $self = {
	     transaction => 0,
	     protocol    => 0,
	     stderr      => 1,
	    };
    
    bless $self, $class;
    $DEBUGGER = $self;
    return $self;
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
	$self->{$key} = $value;
	return $value;
    } else {
	$self->say( "No debug key '$key'" );
	return;
    }
}

sub debug {
    my $self = shift;
    my $required_key = shift;
    my $message = join "", @_;

    return unless $self->get( $required_key );
    
    if ($self->get( 'stderr' )) {
	$self->say( $message );
    } else {
	return $message;
    }
}

sub say {
    my $self = shift;
    my $message = shift;

    print STDERR "$message\n";
}

1;
