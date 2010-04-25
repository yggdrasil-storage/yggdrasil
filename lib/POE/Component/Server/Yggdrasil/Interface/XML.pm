package POE::Component::Server::Yggdrasil::Interface::XML;

use warnings;
use strict;

use XML::Simple;

sub new {
    my $class = shift;
    return bless {}, $class;
}

sub xmlify {
    my ($self, $requestid, $status, $data) = @_;

    my $statusref = $self->_status_xml( $status );

    # We probabaly have some valid data to return to the user, and we
    # can rightfully assume it's an Yggdrasil object or a simple
    # scalar containing a value (property lookup most likely).  Valid
    # types are:
    #
    #  * Entities   (Yggdrasil::Entity)
    #  * Instances  (Yggdrasil::Entity::Instance)
    #  * Properties (Yggdrasil::Property)
    #  * Relations  (Yggdrasil::Relation)
    #  * Users      (Yggdrasil::User)
    #  * Roles      (Yggdrasil::Role)
    #  * <$scalar>  (Value, encode if needed and return)
    
    my $dataref;
    if (ref $data eq 'Yggdrasil::Entity') {
	$dataref = $self->_entity_xml( $data );
    } elsif (ref $data eq 'Yggdrasil::Entity::Instance') {
	$dataref = $self->_instance_xml( $data );	
    } elsif (ref $data eq 'Yggdrasil::Property') {
	$dataref = $self->_property_xml( $data );	
    } elsif (ref $data eq 'Yggdrasil::Relation') {
	$dataref = $self->_relation_xml( $data );	
    } elsif (ref $data eq 'Yggdrasil::User') {
	$dataref = $self->_user_or_role_xml( $data );	
    } elsif (ref $data eq 'Yggdrasil::Role') {
	$dataref = $self->_user_or_role_xml( $data );	
    } elsif (ref $data) {
	# Unknown data reference, that's not good.
	$statusref = $self->xmlify_status( $requestid, 406, "Unknown data type ($data) passed to XML backend" );
    } elsif ($data) {
	$dataref = $self->_scalar_xml( $data );	
    }
        
    my @rid = ();
    @rid = ( requestid => $requestid ) if defined $requestid;
    my @data = ();
    @data = %$dataref if ref $dataref eq 'HASH';
    
    return $self->xmlout( reply => { @rid, %$statusref, @data } );
}

sub _entity_xml {
    my ($self, $entity) = @_;

    my $name = $entity->name();
    my ($start, $stop, $starttime, $stoptime) = $self->_get_times( $entity );

    return { entity => {
			id => $name,
			start => $start,
			stop => $stop,
			starttime => $starttime,
			stoptime => $stoptime,
		       }};
    
}

sub _property_xml {
    my ($self, $property) = @_;
    
    my $name = $property->name();
    my ($start, $stop, $starttime, $stoptime) = $self->_get_times( $property );

    return { property => {
			  id => $name,
			  entity => $property->entity()->name(),
			  start => $start,
			  stop => $stop,
			  starttime => $starttime,
			  stoptime => $stoptime,
			 }};
    
}

sub _instance_xml {
    my ($self, $instance) = @_;
    
    my $name = $instance->id();
    my ($start, $stop, $starttime, $stoptime) = $self->_get_times( $instance );

    return { instance => {
			  id => $name,
			  entity => $instance->entity()->name(),
			  start => $start,
			  stop => $stop,
			  starttime => $starttime,
			  stoptime => $stoptime,
			 }};
    
}

sub _relation_xml {
    my ($self, $relation) = @_;
    
    my $name = $relation->label();
    my ($start, $stop, $starttime, $stoptime) = $self->_get_times( $relation );
    my ($lval, $rval) = $relation->entities();
    
    return { instance => {
			  id => $name,
			  label => $name,
			  lval => $lval->name(),
			  rval => $rval->name(),
			  start => $start,
			  stop => $stop,
			  starttime => $starttime,
			  stoptime => $stoptime,
			 }};
    
}


sub _scalar_xml {
    my ($self, $value, $object) = @_;
    
    # We could use the object, an instance, to check the type of the
    # property and then do the right thing[tm] with the value.  We
    # might wish to base64 a few types, but for now, just pass it
    # through as is.
    return { value => $value };
    
}

sub _user_or_role_xml {
    my ($self, $obj) = @_;

    my $name = $obj->id();
    my ($start, $stop, $starttime, $stoptime) = $self->_get_times( $obj );

    return { user => {
		      id => $name,
		      start => $start,
		      stop => $stop,
		      starttime => $starttime,
		      stoptime => $stoptime,
		     }};
}

sub _status_xml {
    my ($self, $status) = @_;
    return $self->xmlify_status( $status->status(), $status->message());
}

sub xmlify_status {
    my ($self, $retval, $retstr) = @_;
    return { status => { code => $retval, message => $retstr } };
}

sub xmlout {
    my $self = shift;
    my %data = @_;

    return XMLout( \%data, NoAttr => 1, KeyAttr => [], RootName => undef )    
}

sub generate_status_reply {
    my ($self, $requestid, $retval, $retstr) = @_;

    my @rid = ();
    @rid = ( requestid => $requestid ) if defined $requestid;
    return $self->xmlout( reply => { @rid, %{$self->xmlify_status( $retval, $retstr )} } );
}

# Get the ticks and their stamps from an object.  All Yggdrasil
# objects conform to the semantics of "start()", "stop()" and
# "yggdrasil()".
sub _get_times {
    my ($self, $object) = @_;
    my ($start, $stop) = ($object->start(), $object->stop());
    my ($startinfo) = $object->yggdrasil()->get_ticks( $start );
    my ($stopinfo) = $object->yggdrasil()->get_ticks( $stop ) if $stop;
    
    my $starttime  = $startinfo->{stamp};
    my $stoptime   = $stopinfo->{stamp} || '';
    
    return ($object->start(), $object->stop(), $starttime, $stoptime);
}

1;
