package XML::StreamReader;

use strict;
use warnings;

use XML::LibXML;
use IO::Select;

use XML::StreamReader::Handler;

our $MAX_READ = 16_384;

sub new {
    my $class = shift;
    my $self  = {};

    bless $self, $class;

    $self->_init(@_);

    return $self;
}

sub _init {
    my $self   = shift;
    my %params = @_;

    $self->{stream}  = $params{stream};
    die "No stream specificed, aborting initialization" unless $self->{stream};
    $self->{select}  = IO::Select->new( $self->{stream} );

    $self->{handler} = XML::StreamReader::Handler->new();
    $self->{parser}  = XML::LibXML->new( Handler => $self->{handler} );
}

sub read_document {
    my $self = shift;

    do {
	for my $packet ( $self->_read_stream() ) {
	    $self->{parser}->parse_chunk( $packet );
	}
    } while( ! $self->{handler}->document_done() );

    return $self->{parser}->parse_chunk( '', 1 );
}

sub _read_stream {
    my $self = shift;

    # Block until we can read
    my @ready = $self->{select}->can_read();
    my $stream = shift @ready;

    # Set nonblocking so we easily can read all available data on the
    # stream
    my $blocking = $stream->blocking();
    $stream->blocking(0) if $blocking;

    my $buffer;
    my @data;
    while( my $bytes = read( $stream, $buffer, $MAX_READ ) ) {
	push( @data, $buffer );
    }

    $stream->blocking($blocking);

    return @data;
}

1;
