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
    } elsif (ref $data) {
	# Unknown data reference, that's not good.
	$statusref = $self->xmlify_status( 406, "Unknown data type ($data) passed to XML backend" );
	$dataref   = {};
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

    my ($name, $start, $stop) = ($entity->name(), $entity->start(), $entity->stop() || '');
    my ($startinfo) = $entity->yggdrasil()->get_ticks( $start );
    my ($stopinfo) = $entity->yggdrasil()->get_ticks( $stop ) if $stop;
    
    my $starttime  = $stopinfo->{stamp} || '';
    my $stoptime   = $startinfo->{stamp};

    return { entity => {
			name => $name,
			start => $start,
			stop => $stop,
			starttime => $starttime,
			stoptime => $stoptime,
		       }};
    
}

sub _instance_xml {
    my ($self, $instance) = @_;

    my ($name, $start, $stop) = ($instance->id(), $instance->start(), $instance->stop());
    my ($startinfo) = $instance->yggdrasil()->get_ticks( $start );
    my ($stopinfo) = $instance->yggdrasil()->get_ticks( $stop ) if $stop;
    
    my $starttime  = $stopinfo->{stamp} || '';
    my $stoptime   = $startinfo->{stamp};

    return { instance => {
			  id => $name,
			  entity => $instance->entity()->name(),
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

sub generate_status {
    my ($self, $requestid, $retval, $retstr) = @_;

    my @rid = ();
    @rid = ( requestid => $requestid ) if defined $requestid;
    return $self->xmlout( reply => { @rid, %{$self->xmlify_status( $retval, $retstr )} } );
}

1;
