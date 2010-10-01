package Storage::Transaction;

use strict;
use warnings;

our $CURRENT_TRANSACTION;

sub new {
    my $class   = shift;
    my $storage = shift;
    my $self  = $CURRENT_TRANSACTION || bless {}, $class;

    $self->{storage} = $storage;
    $self->{structures} ||= [];
    $self->{subtickid} ||= 0;
    $self->{tickid} ||= 0;

    unless( $self->{level} ) {
	$CURRENT_TRANSACTION = $self;
	$self->{storage}->_start_transaction();
    }

    $self->{level} += 1;
    
    my ($package, $filename, $line, $subroutine, $hasargs,
	$wantarray, $evaltext, $is_require, $hints, $bitmask, $hinthash) = caller(1);

    $self->{storage}->debugger()->debug( 'transaction',
					 "  " x $self->{level} . "Start transaction ($package / $subroutine / $line)" );
    
    return $self;
}

sub get {
    return $CURRENT_TRANSACTION;
}

sub tick_id {
    my $self = shift;
    my $id = shift;

    $self->{tickid} = $id if $id;

    return $self->{tickid};
}

sub sub_tick_id {
    my $self = shift;
    my $p    = shift;
    
    if( $p ) {
	$self->{subtickid} += $p;
    }

    return $self->{subtickid};
}

sub commit {
    my $self = shift;

    my ($package, $filename, $line, $subroutine, $hasargs,
	$wantarray, $evaltext, $is_require, $hints, $bitmask, $hinthash) = caller(1);

    $self->{storage}->debugger()->debug( 'transaction',
					 "  " x $self->{level} . "End transaction ($package / $subroutine / $line)" );
    $self->{level} -= 1;
    return if $self->{level};

    # Actually commit
    $self->{storage}->_commit();

    $self->_reset();
}

sub rollback {
    my $self = shift;

    #rollback
#    unless( $CURRENT_TRANSACTION ) {
#	print "Calling rollback when CURRENT_TRANSACTION is undef\n";
#	use Carp qw(cluck confess);
#	confess();
#    }

    my ($package, $filename, $line, $subroutine, $hasargs,
	$wantarray, $evaltext, $is_require, $hints, $bitmask, $hinthash) = caller(1);

    $self->{storage}->debugger()->debug( 'transaction',
					 "  " x $self->{level} . "ROLLBACK ($package / $subroutine / $line)" );
    $self->{level} -= 1;
#    cluck();
    $self->{storage}->_rollback();

    $self->_reset();
}

sub define {
    my $self = shift;
    my $schema = shift;

    push( @{ $self->{structures} }, $schema );
}

sub _reset {
    my $self = shift;

    # reset counter object
    $CURRENT_TRANSACTION = undef;

}

sub __DESTROY__ {
    my $self = shift;

    my ($package, $filename, $line, $subroutine, $hasargs,
	$wantarray, $evaltext, $is_require, $hints, $bitmask, $hinthash) = caller(1);

    $self->{storage}->debugger()->debug( 'transaction',
					 "  " x $self->{level} . "Implicit rollback! ($package / $subroutine / $line)" );
    $self->{level} -= 1;


#    $self->rollback();
}

1;
