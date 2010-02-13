package Yggdrasil::Transaction;

use strict;
use warnings;

use Storable qw|dclone|;

our $COUNT = 1;
our @STACK;

sub create_singleton {
    my $class = shift;
    my $self  = bless {}, $class;

    return $self->_initialize_internal_structure();
}

sub _initialize_internal_structure {
    my $self = shift;
    my %params = @_;

    $self->{id} = $COUNT++;
    $self->{path} = $params{path} || 'system';
    $self->{log} = [];
    $self->{engine} = [];
    return $self;
}

sub _has_data {
    my $self = shift;

    if (@{$self->{log}} || @{$self->{engine}}) {
	return 1;
    }
    
    return undef;
}

sub init { 
    my $self = shift;
    my %params = @_;

    if ($self->_has_data() && ! $self->_is_commited() ) {
	unless ($self->_is_system_initiated()) {
	    print "WARNING, transaction in progress, commiting NOW!\n"
	}
	$self->commit();
    }

    return $self->_initialize_internal_structure( %params );
}

sub id {
    my $self = shift;
    return $self->{id};   
}

sub path {
    my $self = shift;
    return $self->{path},
}

sub log {
    my $self = shift;
    my $entry = shift;

    push @{$self->{log}}, $entry;
}

sub engine {
    my $self = shift;
    my $entry = shift;

    push @{$self->{engine}}, $entry;    
}

sub get_commit_log {
    my $self = shift;
    return @{$self->{log}};
}

sub get_engine_log {
    my $self = shift;
    return @{$self->{engine}};
}

sub get_stack {
    return @STACK;
}

sub clear_stack {
    @STACK = ();
    return;
}

sub commit {    
    my $self = shift;
    
    # add commit code.  ;-)
#    print "Committing ", $self->name(), "\n";
#    for my $entry ($self->get_commit_log()) {
#	print " ** $entry\n";
#    }

    $self->_is_commited( 1 );
    $self->_push_to_stack( dclone $self );    
}

sub _push_to_stack {
    my $self = shift;
    push @STACK, shift;
}

sub _is_system_initiated {
    my $self = shift;
    
    if ($self->{path} eq 'system') {
	return 1;
    } else {
	return 0;
    } 
}

sub _is_user_initiated {
    my $self = shift;
    return ! $self->_is_system_initiated();
}

sub _is_commited {
    my $self = shift;
    my $yep  = shift;
    $self->{committed} = $yep if $yep;
    return $self->{committed};
}

sub __DESTROY__ {
    my $self = shift;
    if ($self->_has_data()) {
	print "WARNING, transaction leaving scope without explicit commit, commiting NOW!\n";
	$self->commit();
    }
}

1;
