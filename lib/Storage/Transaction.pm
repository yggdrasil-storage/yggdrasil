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
    print "  " x $self->{level}, "Start transaction\n";

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

    print "  " x $self->{level}, "End transaction\n";
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
#    print "-" x 79, "\n";
#    print "ROLLBACK!\n";
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

#    $self->rollback();
}

1;
