package Yggdrasil::Remote::Client::XML;

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
    $self->{status}    = $params{status};

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

sub get_status {
    my $self = shift;
    return $self->{status};
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

    if ($type eq 'whoami' || $type eq 'uptime' || $type eq 'info' || $type eq 'role_add_user' || $type eq 'role_remove_user' || $type eq 'role_grant' || $type eq 'role_revoke') {
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
    print $xmlout, "\n" if $self->{_debug}->{protocol};
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
    my ($self, $eid, $pid, $type, $nullp) = @_;
    return $self->_define( 'property', entityid => $eid, propertyid => $pid, type => $type, nullp => $nullp );
}

sub expire_property {
    my ($self, $eid, $pid) = @_;
    return $self->_expire( 'property', entityid => $eid, propertyid => $pid );    
}

sub get_property_meta {
    my ($self, $eid, $pid, $meta) = @_;
    return $self->_get(
		       'property_meta',    entityid => $eid,
		       propertyid => $pid, meta     => $meta,
		      );
}

# Relation interface
sub get_relation {
    my ($self, $id) = @_;
    return $self->_get( 'relation', relationid => $id );    
}

sub define_relation {
    my ($self, $id, $lval, $rval) = @_;

    my @idlist = ();
    @idlist = ( 'relationid' => $id ) if $id;
    
    return $self->_define( 'relation', @idlist, lval => $lval, rval => $rval );
}

sub relation_bind {
    my ($self, $id, $lval, $rval) = @_;

    return $self->_define( 'relation_bind', relationid => $id, lval => $lval, rval => $rval );
}

sub expire_relation {
    my ($self, $id) = @_;
    return $self->_expire( 'relation', relationid => $id );    
}

sub relation_participants {
    my ($self, $id) = @_;
    return $self->_get( 'relation_participants', relationid => $id );
}

# Instance interface.  Interestingly enough, instances aren't defined,
# only created.
sub get_instance {
    my ($self, $eid, $id, $time) = @_;
    return $self->_get( 'instance', entityid => $eid, instanceid => $id, time => $time );
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
    my ($self, $eid, $pid, $id, $time) = @_;
    return $self->_get( 'value', entityid => $eid, propertyid => $pid, instanceid => $id, time => $time );
}

sub set_value {
    my ($self, $eid, $pid, $id, $value) = @_;
    return $self->_set( 'value',
			entityid   => $eid, propertyid => $pid,
			instanceid => $id,  value => $value );
}

# User interface
sub get_user {
    my ($self, $uid) = @_;
    return $self->_get( 'user', userid => $uid );
}

sub expire_user {
    my ($self, $uid) = @_;
    return $self->_expire( 'user', userid => $uid );
}

sub get_user_value {
    my ($self, $uid, $key) = @_;
    return $self->_get( 'user_value', userid => $uid, propertyid => $key );
}

sub set_user_value {
    my( $self, $uid, $key, $val ) = @_;
    return $self->_set( 'user_value', userid => $uid, propertyid => $key, value => $val );
}

sub get_roles_of {
    my ($self, $uid) = @_;
    return $self->_get( 'roles_of', userid => $uid );
}

# Role interface
sub define_role {
    my ($self, $rid) = @_;
    return $self->_define( 'role', roleid => $rid );
}

sub get_role {
    my ($self, $rid) = @_;
    return $self->_get( 'role', roleid => $rid );
}

sub get_role_value {
    my ($self, $rid, $key) = @_;
    return $self->_get( 'role_value', roleid => $rid, propertyid => $key );
}

sub set_role_value {
    my ($self, $rid, $key, $val) = @_;
    return $self->_set( 'role_value', roleid => $rid, propertyid => $key, value => $val );
}

sub get_members {
    my ($self, $rid) = @_;
    return $self->_get( 'members', roleid => $rid );
}

sub role_add_user {
    my ($self, $rid, $uid ) = @_;
    return $self->_get( 'role_add_user', roleid => $rid, userid => $uid );
}

sub role_remove_user {
    my ($self, $rid, $uid ) = @_;
    return $self->_get( 'role_remove_user', roleid => $rid, userid => $uid );
}

sub role_grant {
    my ($self, $rid, $schema, $mode, $id, $idvalue) = @_;
    return $self->_get( 'role_grant',
			roleid => $rid,
			schema => $schema,
			mode   => $mode,
			id     => $idvalue );
}

sub role_revoke {
    my ($self, $rid, $schema, $mode, $id, $idvalue) = @_;
    return $self->_get( 'role_revoke',
			roleid => $rid,
			schema => $schema,
			mode   => $mode,
			id     => $idvalue );
}

# Slurps.
sub get_all_entities {
    my $self = shift;
    return $self->_get( 'all_entities', @_ );
}

sub get_all_users {
    my $self = shift;
    return $self->_get( 'all_users', @_ );
}

sub get_all_relations {
    my $self = shift;
    return $self->_get( 'all_relations', @_ );
}

sub get_all_roles {
    my $self = shift;
    return $self->_get( 'all_roles', @_ );
}

sub get_all_instances {
    my $self   = shift;
    my $entity = shift;
    return $self->_get( 'all_instances', entityid => $entity, @_ );
}

sub get_all_entity_relations {
    my $self   = shift;
    my $entity = shift;
    return $self->_get( 'all_entity_relations', entityid => $entity, @_ );
}

sub get_all_properties {
    my $self   = shift;
    my $entity = shift;
    return $self->_get( 'all_properties', entityid => $entity, @_ );
}

sub search {
    my $self = shift;
    my %params = @_;
    return $self->_get( 'search', search => $params{search} );
}

# Metaish stuff
# FIXME: Need to be able to send requests for multiple ticks.
sub get_ticks {
    my $self = shift;
    return $self->_get( 'ticks', @_ );
}

sub get_ticks_by_time {
    my $self = shift;

    if (@_ == 2) {
	return $self->_get( 'ticks_by_time', start => shift, stop => shift );	
    } elsif (@_ == 1) {
	return $self->_get( 'ticks_by_time', start => shift );	
    } else {
	return $self->_get( 'ticks_by_time' );	
    }
}

sub property_types {
    my $self = shift;
    return $self->_get( 'property_types' );
}

sub get_current_tick {
    my $self = shift;
    return $self->_get( 'current_tick' );
}

sub can {
    my $self = shift;
    my ($operation, $schema) = (shift, shift);
    my $hashref = shift;
    my $key = (keys %$hashref)[0];

    return $self->_get( 'can', operation => $operation, target => $schema,
			key => $key, value => $hashref->{$key} );
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

sub info {
    my $self = shift;
    return $self->_get( 'info' );
}

sub yggdrasil {
    my $self = shift;
    return $self->_get( 'info' );
}

# Reply handling.  This is done by calling _get_reply(), which will
# gather up one (complete) XML document, break it apart abit for
# status checkups (_get_reply_status) and process the data part of the
# reply via _pair() before returning the object to the Yggdrasil
# calling class, that'll make this into a proper object.
sub _get_reply {
    my $self = shift;
    my $reply_node = shift;
    
    my $reply = $self->parser()->read_document();
    $reply->dump() if $self->{_debug}->{protocol};
    my $s = $self->_get_reply_status( $reply );
    return unless $s->OK();

    if ($reply_node eq 'all_entities') {
	$reply_node = 'entity';
    } elsif ($reply_node eq 'all_entity_relations') {
	$reply_node = 'relation';
    } elsif ($reply_node eq 'all_users') {
	$reply_node = 'user';
    } elsif ($reply_node eq 'all_roles') {
	$reply_node = 'role';
    } elsif ($reply_node eq 'all_instances') {
	$reply_node = 'instance';
    } elsif ($reply_node eq 'all_properties') {
	$reply_node = 'property';
    } elsif ($reply_node eq 'all_relations') {
	$reply_node = 'relation';
    } elsif ($reply_node eq 'property_meta') {
	$reply_node = 'value';
    } elsif ($reply_node eq 'roles_of') {
	$reply_node = 'role';
    } elsif ($reply_node eq 'members') {
	$reply_node = 'user';
    } elsif ($reply_node eq 'ticks') {
	$reply_node = 'hash';
    } elsif ($reply_node eq 'user_value') {
	$reply_node = 'value';
    } elsif ($reply_node eq 'role_value') {
	$reply_node = 'value';
    } elsif ($reply_node eq 'property_types') {
	$reply_node = 'value';
    } elsif ($reply_node eq 'relation_participants') {
	$reply_node = 'hash';
    } elsif ($reply_node eq 'addremove_user') {
	$reply_node = 'value';
    } elsif ($reply_node eq 'relation_bind') {
	$reply_node = 'relation';
    } elsif ($reply_node eq 'current_tick') {
	$reply_node = 'value';
    } elsif ($reply_node eq 'ticks_by_time') {
	$reply_node = 'hash';
    } elsif ($reply_node eq 'can') {
	$reply_node = 'value';
    }

    my @data;
    if ($reply_node eq 'search') {
	# Search returns any number of objects from any of the four
	# default types.  Check for all of them, order isn't relevant
	# as we'll have to manually dig up the structures type again
	# later.  The reason for this is (probably) that _pair only
	# deals with a list and we don't have any pretty way of doing
	# multiple _pairs in a query.
	for my $node_type (qw/entity instance property relation/) {
	    my @ret = $reply->get( 'reply', $node_type );
	    push @data, @ret;
	}
    } else {
	@data = $reply->get( 'reply', $reply_node );
    }
    
    if ($s->OK()) {
	my $req  = $reply->get( q/reply requestid/ );
	return $self->_pair( $reply_node, @data );
    } else {
	return undef;
    }
}

sub _get_reply_status {
    my $self = shift;
    my $data = shift;

    my $stat = $data->get( qw/reply status/ );
    my $code = $stat->get( 'code' )->text();

    my $s = $self->get_status();
    $s->set( $code, $stat->get( 'message' )->text() );
    return $s;
}

# Turns the data set into a key <-> value pair set that the
# objectifier can deal with.  This code assumes that all data relevant
# to object creation is encapsulated in a flat element structure
# generated via XML::StreamParser (values are contained within the
# _text-key under a hash element in question).
sub _pair {
    my $self = shift;
    my $type = shift;
    return unless @_;
    my @sets;

    if ($type eq 'value' || $type eq 'uptime' || $type eq 'whoami') {
	return wantarray ? map { $_->text() } @_ : $_[0]->text();
    }
    
    for my $data (@_) {
	my %pair;

	# Okay, search can feed us empty structures.  Not very pretty,
	# but at least we should handle it.
	next unless $data;
	
	# Set the type of structure, search will need this as stuff is
	# returned in a flat list.
	$pair{_type} = lc $data->{tag};
	
	for my $k ( $data->children() ) {
	    my $tag = $k->tag();
	    if ($tag eq 'id') {
		$pair{'name'} = $k->text();
	    } elsif ($tag eq 'start' || $tag eq 'stop' || $tag eq 'realstart' || $tag eq 'realstop') {
		$pair{"_$tag"} = $k->text();
		next;
	    } elsif ($tag eq '_internal_id') {
		$pair{_id} = $k->text();
		next;
	    }
	    
	    $pair{$tag} = $k->text() || '';
	}
	push @sets, \%pair;
    }

    if (wantarray) {
	return @sets;
    } else {
	return $sets[0];
    }
}

1;
