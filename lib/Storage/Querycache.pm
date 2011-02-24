package Storage::Querycache;

use strict;
use warnings;

sub new {
    my $class = shift;
    
    my $self = { @_ };

    $self->{query}     = {};
    $self->{schemamap} = {};
    
    return bless $self, $class;
}

sub storage {
    my $self = shift;
    return $self->{storage};
}

sub debugger {
    my $self = shift;
    return $self->storage()->debugger();
}

sub get {
    my ($self, $sql, $params) = @_;

    my $key = $self->_keygen( $sql, $params );
    my $hit = $self->{query}->{$key};

    if ($hit) {
	$self->debugger()->debug( 'cache', "H: $key" );
	$self->debugger()->activity( 'cache', 'hit' );
    } else {
	$self->debugger()->debug( 'cache', "M: $key" );
	$self->debugger()->activity( 'cache', 'miss' );
    }
    
    return $hit;
}

sub set {
    my ($self, $sql, $params, $value, $schemas) = @_;
    my $key = $self->_keygen( $sql, $params );

    
    for my $s (@$schemas) {
	$self->{schemamap}->{$s} ||= [];
	push @{$self->{schemamap}->{$s}}, $key;
    }

    $self->debugger()->debug( 'cache', "A: $key" );
    $self->debugger()->activity( 'cache', 'add' );

    return $self->{query}->{$key} = $value;
}

sub delete {
    my ($self, $schema) = @_;
    my $ref = $self->{schemamap}->{$schema};
    return unless $ref;
    
    for my $stm (@$ref) {
	delete $self->{query}->{$stm};
    }
    
    $self->debugger()->debug( 'cache', "D: $schema" );
    $self->debugger()->activity( 'cache', 'delete' );
    delete $self->{schemamap}->{$schema};
}

sub _keygen {
    my ($self, $sql, $params) = @_;

    return $sql . ' => ' . join(',', @$params);
}

1;
