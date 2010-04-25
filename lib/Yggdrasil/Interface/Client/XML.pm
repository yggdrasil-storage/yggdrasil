package Yggdrasil::Interface::Client::XML;

use warnings;
use strict;

use IO::Socket::SSL;
use XML::StreamReader;
use XML::Simple;

sub new {
    my $class  = shift;
    my %params = @_;
    
    my $self  = bless {}, $class;

    $self->{stream}    = $params{stream};
    $self->{parser}    = XML::StreamReader->new( stream => $params{stream} );
    $self->{yggdrasil} = $params{yggdrasil};

    my $i = 1;
    $self->{nextrequestid} = sub { return $i++ };
    $self->{requestid} = sub { return $i };
    
    return $self;
}

sub get_entity {
    my $self = shift;
    my $id   = shift;
    
    $self->execute( requestid => $self->{nextrequestid}->(),
		    exec      => 'get_entity',
		    entityid  => $id,
		  );

    $self->_get_reply( 'entity' );
}

sub execute {
    my $self   = shift;
    my $xmlout = $self->xmlout( yggdrasil => { request => { @_ } } );

    my $stream = $self->{stream};
    print $stream $xmlout;

}

sub _get_reply {
    my $self = shift;
    my $reply_node = shift;
    
    my $reply = $self->parser()->read_document();
    my $stat = $reply->{yggdrasil}->{reply}->{status};
    my $code = $stat->{code}->{_text};

    if ($code !~ /^2../) {
	my $s = $self->get_status();
	$s->set( $code, $stat->{message}->{_text} );
	return;
    }
    
    my $data = $reply->{yggdrasil}->{reply}->{$reply_node};
    my $req  = $reply->{yggdrasil}->{reply}->{requestid};

    # Objectify right about here.    
    printf "%20s - %s\n", 'requestid', $req->{_text};
    for my $k (keys %$data) {
	next if $k =~ /^_/;
	printf "%20s - %s\n", $k, $data->{$k}->{_text}?$data->{$k}->{_text}:'';
    } 
}


sub xmlout {
    my $self = shift;
    my %data = @_;

    return XMLout( \%data, NoAttr => 1, KeyAttr => [], RootName => undef )    
}

sub parser {
    my $self = shift;
    return $self->{parser};
}

sub yggdrsail {
    my $self = shift;
    return $self->{yggdrasil};    
}

sub get_status {
    my $self = shift;
    return $self->{yggdrasil}->get_status();
}

1;
