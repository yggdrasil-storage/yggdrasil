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

    my $root = $self->{root};
    $self->_reset();

    return $root;
}

sub start_element {
    my( $self, $data ) = @_;

    my $stack = $self->{stack};
    my $node = Node->new( $data->{Name} );

    for my $attr ( values %{ $data->{Attributes} } ) {
	$node->attr( $attr->{Name}, $attr->{Value} );
    }

    unless( $stack->isempty() ) {
	$stack->peek()->add_child( $node );
    }

    $stack->push( $node );
}

sub end_element {
    my( $self, $data ) = @_;

    my $stack = $self->{stack};
    my $node = $stack->pop();

    if( $node->tag() ne $data->{Name} ) {
	die "Unbalanced tag $data->{Name}\n";
    }

    $self->{root} = $node;
}


sub characters {
    my( $self, $data ) = @_;
    
    my $stack = $self->{stack};
    $stack->peek()->text( $data->{Data} );
}

sub _reset {
    my $self = shift;

    $self->{stack} = Stack->new();
    $self->{root} = undef;
}

sub document_done {
    my $self = shift;

    return 1 if $self->{stack}->isempty();
    return;
}

package Node;

use strict;
use warnings;

sub new {
    my $class = shift;
    my $tag   = shift;

    return bless {
	children => {},
	attrs    => {},
	text     => undef,
	tag      => $tag,
    }, $class;
}

sub add_child {
    my $self  = shift;
    my $child = shift;

    my $childtag = $child->tag();

    my $list = $self->{children}->{$childtag} ||= [];
    push( @$list, $child );
}

sub children {
    my $self = shift;

    return map { @$_ } values %{ $self->{children} };
}

sub attr {
    my $self = shift;

    
    if( @_ && ! scalar @_ % 2 ) {
	my %attrs = @_;
	foreach my $key ( keys %attrs ) {
	    $self->{attr}->{$key} = $attrs{$key};
	}
    } elsif( @_ ) {
	my $key = shift;
	return $self->{attr}->{$key};
    } else {
	return keys %{ $self->{attr} };
    }
}

sub text {
    my $self = shift;

    if( @_ ) {
	$self->{text} .= shift;
    }

    return $self->{text};
}

sub tag {
    my $self = shift;

    if( @_) {
	$self->{tag} = shift;
    }

    return $self->{tag};
}

sub get {
    my $self = shift;
    my $top  = shift;
    my @path = @_;

    my $children = $self->{children}->{$top};
    return unless $children;

    unless( @path ) {
	return wantarray() ? @$children : $children->[0];
    }

    my @list;
    foreach my $child ( @$children ) {
	push( @list, $child->get(@path) );
    }

    return wantarray() ? @list : $list[0];
}

sub dump {
    my $self = shift;
    my $lvl  = shift || 0;

    my $indent = "    ";

    print $indent x $lvl;
    print "<", $self->tag();

    my @attrs;
    for my $attr ( $self->attr() ) {
	my $value = $self->attr( $attr );
	$value =~ s/"/\\"/g;
	push( @attrs, join("=", $attr, qq<"$value">) );
    }
    
    if( @attrs ) {
	print " ";
	print join(" ", @attrs);
    }

    print ">";

    my @children = $self->children();
    print "\n" if @children;

    my $text = $self->text();
    print $text if $text && $text =~ /\S/;
    
    for my $child ( @children ) {
	$child->dump( $lvl+1 );
    }

    print $indent x $lvl if @children;
    print "</", $self->tag(), ">\n";
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
