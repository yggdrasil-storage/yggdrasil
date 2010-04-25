package XML::StreamReader::Handler;

use strict;
use warnings;

sub new {
    my $class = shift;
    my $self  = {};

    bless $self, $class;

    $self->_reset();

    return $self;
}

sub start_document {}
sub xml_decl {}
 
sub end_document {
    my( $self, $data ) = @_;

    my $root = $self->{stack}->pop();
    $self->_reset();

    return $root;
}

sub start_element {
    my( $self, $data ) = @_;

    my $stack = $self->{stack};
    my $node;
    if( $stack->isempty() ) {
	$node = {};
	$stack->push( $node );
    } else {
	$node = $stack->peek();
    }

    my $child = $node->{ $data->{Name} } = {};
    
    $child->{_attr} = {};
    for my $attr ( values %{ $data->{Attributes} } ) {
	$child->{_attr}->{ $attr->{Name} } = $attr->{Value};
    }

    $stack->push( $child );
}

sub end_element {
    my( $self, $data ) = @_;

    my $stack = $self->{stack};
    $stack->pop();
    
    my $node = $stack->peek();
    if( ! exists $node->{ $data->{Name} } ) {
	die "Unbalanced tag $data->{Name}\n";
    }
}

sub characters {
    my( $self, $data ) = @_;

    my $stack = $self->{stack};
    $stack->peek()->{_text} .= $data->{Data};
}

sub _reset {
    my $self = shift;

    $self->{stack} = Stack->new();
}

sub document_done {
    my $self = shift;

    if( $self->{stack}->size() == 1 ) {
	return 1;
    }

    return;
}

package Stack;

use strict;
use warnings;

sub new {
    my $class = shift;
    my $self  = [];

    return bless $self, $class;
}

sub pop {
    my $self = shift;

    return pop @$self;
}

sub push {
    my $self = shift;

    push( @$self, @_ );
}

sub peek {
    my $self = shift;

    return $self->[-1];
}

sub isempty {
    my $self = shift;

    return @$self ? 0 : 1;
}

sub size {
    my $self = shift;

    return scalar @$self;
}

1;
