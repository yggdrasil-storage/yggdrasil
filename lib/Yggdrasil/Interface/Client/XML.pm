package Yggdrasil::Interface::Client::XML;

use warnings;
use strict;

use Yggdrasil::Interface::Objectify;

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
    $self->{objectify} = Yggdrasil::Interface::Objectify->new();

    my $i = 1;
    $self->{nextrequestid} = sub { return $i++ };
    $self->{requestid} = sub { return $i };
    
    return $self;
}

sub _get {
    my $self = shift;
    my $type = shift;
    my @keys = @_;
    my $req  = $self->{nextrequestid}->();
    my $exec = 'get_' . $type;

    if ($type eq 'whoami' || $type eq 'uptime') {
	$exec = $type;
	$type = 'value';
    }
    
    $self->execute( requestid => $req,
		    exec      => $exec,
		    @keys,
		  );
    return $self->_get_reply( $type, $req );
}

sub get_entity {
    my $self = shift;
    my $id   = shift;

    return $self->_get( 'entity', entityid => $id );
}

sub get_property {
    my $self = shift;
    my $eid  = shift;
    my $pid  = shift;

    return $self->_get( 'property', entityid => $eid, propertyid => $pid );    
}

sub get_relation {
    my $self = shift;
    my $id   = shift;

    return $self->_get( 'relation', relationid => $id );    
}

sub get_instance {
    my $self = shift;
    my $eid  = shift;
    my $id   = shift;

    return $self->_get( 'instance', entityid => $eid, instanceid => $id );    
}

sub get_value {
    my $self = shift;
    my $eid  = shift;
    my $pid  = shift;
    my $id   = shift;

    return $self->_get( 'value', entityid => $eid, propertyid => $pid, instanceid => $id );    
}

sub uptime {
    my $self = shift;
    return $self->_get( 'uptime' );
}

sub whoami {
    my $self = shift;
    return $self->_get( 'whoami' );
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

    my $s = $self->get_reply_status( $reply );
    return unless $s->OK();
    
    my $data = $reply->{yggdrasil}->{reply}->{$reply_node};
    my $req  = $reply->{yggdrasil}->{reply}->{requestid};

    return $self->{objectify}->parse( $self->_pair( $data, $reply_node ));
}

sub get_reply_status {
    my $self = shift;
    my $data = shift;

    my $stat = $data->{yggdrasil}->{reply}->{status};
    my $code = $stat->{code}->{_text};
    
    my $s = $self->get_status();
    $s->set( $code, $stat->{message}->{_text} );
    return $s;
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

# Turns the data set into a key <-> value pair set that the
# objectifier can deal with.  This code assumes that all data relevant
# to object creation is encapsulated in a flat element structure
# generated via XML::StreamParser (values are contained within the
# _text-key under a hash element in question).
sub _pair {
    my $self = shift;
    my $data = shift;
    my $type = shift;
    my %pair;
    $pair{$type} = 1;

    if ($type eq 'value' || $type eq 'uptime' || $type eq 'whoami') {
	$pair{'value'} = $data->{_text};
    } else {
	for my $k (keys %$data) {
	    next if $k =~ /^_/;
	    $pair{$k} = $data->{$k}->{_text} || '';
	}
    }
    
    return \%pair;
}

1;
