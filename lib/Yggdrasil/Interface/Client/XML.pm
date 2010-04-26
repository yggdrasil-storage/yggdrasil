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

# Command interface.  The two parameters are the type (entity /
# property etc) of the action, and the action (define / get / set)
# itself.
sub _exec {
    my $self = shift;
    my $type = shift;
    my $command_type = shift;
    my @keys = @_;
    my $req  = $self->{nextrequestid}->();
    my $exec = $command_type . '_' . $type;

    if ($type eq 'whoami' || $type eq 'uptime') {
	$exec = $type;
	$type = 'value';
    }
    
    $self->_execute( requestid => $req,
		     exec      => $exec,
		     @keys,
		   );
    return $self->_get_reply( $type, $req );
}

sub _get {
    my $self = shift;
    my $type = shift;
    return $self->_exec( $type, 'get', @_ );
}

sub _define {
    my $self = shift;
    my $type = shift;
    return $self->_exec( $type, 'define', @_ );
}

sub _create {
    my $self = shift;
    my $type = shift;
    return $self->_exec( $type, 'create', @_ );
}

sub _set {
    my $self = shift;
    my $type = shift;
    return $self->_exec( $type, 'set', @_ );
}

sub _expire {
    my $self = shift;
    my $type = shift;
    return $self->_exec( $type, 'expire', @_ );
}

# Execute does the actual stream / socket writing, as well as
# XMLifying the output from _exec.
sub _execute {
    my $self   = shift;
    my $xmlout = $self->xmlout( yggdrasil => { request => { @_ } } );

    my $stream = $self->{stream};
    print $stream $xmlout;
}

# Entity interface.
sub get_entity {
    my ($self, $id) = @_;
    return $self->_get( 'entity', entityid => $id );
}

sub define_entity {
    my ($self, $id) = @_;
    return $self->_define( 'entity', entityid => $id );
}

sub expire_entity {
    my ($self, $id) = @_;
    return $self->_expire( 'entity', entityid => $id );
}

# Property interface.
sub get_property {
    my ($self, $eid, $pid) = @_;
    return $self->_get( 'property', entityid => $eid, propertyid => $pid );    
}

sub define_property {
    my ($self, $eid, $pid) = @_;
    return $self->_define( 'property', entityid => $eid, propertyid => $pid );    
}

sub expire_property {
    my ($self, $eid, $pid) = @_;
    return $self->_expire( 'property', entityid => $eid, propertyid => $pid );    
}

# Relation interface
sub get_relation {
    my ($self, $id) = @_;
    return $self->_get( 'relation', relationid => $id );    
}

sub define_relation {
    my ($self, $id) = @_;
    return $self->_define( 'relation', relationid => $id );    
}

sub expire_relation {
    my ($self, $id) = @_;
    return $self->_expire( 'relation', relationid => $id );    
}

# Instance interface.  Interestingly enough, instances aren't defined,
# only created.
sub get_instance {
    my ($self, $eid, $id) = @_;
    return $self->_get( 'instance', entityid => $eid, instanceid => $id );
}

sub create_instance {
    my ($self, $eid, $id) = @_;
    return $self->_create( 'instance', entityid => $eid, instanceid => $id );
}

sub expire_instance {
    my ($self, $eid, $id) = @_;
    return $self->_expire( 'instance', entityid => $eid, instanceid => $id );
}

# Value interface, can't be defined, only set.
sub get_value {
    my ($self, $eid, $pid, $id) = @_;
    return $self->_get( 'value', entityid => $eid, propertyid => $pid, instanceid => $id );    
}

sub set_value {
    my ($self, $eid, $pid, $id, $value) = @_;
    return $self->_set( 'value',
			entityid   => $eid, propertyid => $pid,
			instanceid => $id,  value => $value );
}

# Introspective calls, handle with care.
sub uptime {
    my $self = shift;
    return $self->_get( 'uptime' );
}

sub whoami {
    my $self = shift;
    return $self->_get( 'whoami' );
}

# Reply handling.  This is done by calling _get_reply(), which will
# gather up one (complete) XML document, break it apart abit for
# status checkups (_get_reply_status) and process the data part of the
# reply via _pair() before feeding the results to the objectifier
# which returns the results.  Ideally, this should return a proper
# Yggdrasil object.
sub _get_reply {
    my $self = shift;
    my $reply_node = shift;

    my $reply = $self->parser()->read_document();

    my $s = $self->_get_reply_status( $reply );
    return unless $s->OK();
    
    my $data = $reply->{yggdrasil}->{reply}->{$reply_node};

    if ($s->OK()) {
	my $req  = $reply->{yggdrasil}->{reply}->{requestid};
	return $self->{objectify}->parse( $self->_pair( $data, $reply_node ));
    } else {
	print $s->status(), ", ", $s->message();
	return undef;
    }
    
}

sub _get_reply_status {
    my $self = shift;
    my $data = shift;

    my $stat = $data->{yggdrasil}->{reply}->{status};
    my $code = $stat->{code}->{_text};
    
    my $s = $self->get_status();
    $s->set( $code, $stat->{message}->{_text} );
    return $s;
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
