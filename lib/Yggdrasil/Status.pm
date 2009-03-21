package Yggdrasil::Status;

use strict;
use warnings;

# Status code map
my %map = (
	   # 100 series, continue please.
	   100 => 'Continue',
	   
	   # 200 series, things went well.  OK.
	   200 => 'OK',
	   201 => 'Created',
	   202 => 'Accepted', # no return value, batched.
	   203 => 'Non-authorative information', # cached?
	   204 => 'No content',

	   # 300 series, things are moved, but the request
	   # is still processed and returned OK.
	   301 => 'Moved permanently',
	   303 => 'See other',
	   
	   # 400 series, no go.  Not OK.
	   400 => 'Bad request',
	   401 => 'Unauthorized',
	   403 => 'Forbidden',
	   404 => 'Not found',
	   406 => 'Not acceptable',
	   409 => 'Conflict',
	   410 => 'Gone',
	   
	   # 500 series, internal errors.  Not OK.
	   500 => 'Internal error',
	   501 => 'Not implemented',
	   503 => 'Service unavailable', # temporary.
	   599 => 'Malformed status code',
	  );
  
sub new {
  my $class = shift;
  my $self  = {
	       stack     => [],
	       stacksize => 10,
	      };

  return bless $self, $class;
}

sub set {
    my $self = shift;
    my $code = shift;
    my $msg  = shift || '';

    if ($map{$code}) {
	$self->_update( $code, $msg );	
	return $code;
    } else {
	$self->_update( '599', $msg );
	return 599;
    }
}

sub status {
    my $self = shift;
    return $self->_current()->[0];
}

sub english {
    my $self = shift;
    return $map{$self->status()};
}

sub message {
    my $self = shift;
    return $self->_current()->[1];
}

sub context {
    my $self = shift;
    my $current = $self->_current();

    my $line = $current->[2];
    my $file = $current->[3];
    my $sub  = $current->[4];
    
    return "$file:$line ($sub)";
}

sub OK {
    my $self = shift;
    my $current = $self->status();

    # Remember, Yggdrasil deals with moved structures, so moved is OK.
    # If the user wishes to deal with it, that can be checked
    # specifically.
    if ($current >= 200 && $current < 400) {
	return 1;
    } else {
	return 0;
    }
}

sub get {
    my $self  = shift;
    my $start = shift || 0;
    my $stop  = shift || 0;
    
    my @list = @{$self->{stack}}[$start .. $stop];
    
    if (wantarray) {
	return @list;
    } else {
	if (@list > 1) {
	    return \@list;
	} else {
	    return $list[0];
	}
    }
}

sub _current {
    my $self = shift;
    my $cur = $self->{stack}->[0];
    if ($cur) {
	return $cur;
    }  else {
	return [ '500', 'Status not set before called?' ];
    }
}

sub _update {
    my $self = shift;
    my $code = shift; # Verified as existing;
    my $msg  = shift; # Value is set.

    # Skip the call to set, find the real caller.  This really isn't
    # working well...
    my ($file, $line, $sub) = (caller(2))[1 .. 3];
    
    # Update the stack.
    unshift @{$self->{stack}}, [ $code, $msg, $file, $line, $sub ];
    
    if (scalar @{$self->{stack}} > $self->{stacksize}) {
 	pop @{$self->{stack}};
    }
}

1;
