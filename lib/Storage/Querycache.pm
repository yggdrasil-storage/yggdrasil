package Storage::Querycache;

use strict;
use warnings;

sub new {
    my $class = shift;

    my $self = {};

    $self->{query}     = {};
    $self->{schemamap} = {};
    
    return bless $self, $class;
}

sub get {
    my ($self, $sql, $params) = @_;
    
    return $self->{query}->{$self->_keygen( $sql, $params )};
}

sub set {
    my ($self, $sql, $params, $value, $schemas) = @_;
    
    for my $s (@$schemas) {
	$self->{schemamap}->{$s} ||= [];
	push @{$self->{schemamap}->{$s}}, $self->_keygen( $sql, $params );
    }

    return $self->{query}->{$self->_keygen( $sql, $params )} = $value;
}

sub delete {
    my ($self, $schema) = @_;
    my $ref = $self->{schemamap}->{$schema};
    return unless $ref;
    
    for my $stm (@$ref) {
	delete $self->{query}->{$stm};
    }
    delete $self->{schemamap}->{$schema};
}

sub _keygen {
    my ($self, $sql, $params) = @_;

    return join(',', $sql, @$params);
}

1;
