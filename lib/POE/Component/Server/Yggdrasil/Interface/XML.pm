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
    return $self->xmlout( reply => { $statusref } ) unless $data;

    # We now have some valid data to return to the user, and we can
    # rightfully assume it's an Yggdrasil object or a simple scalar
    # containing a value (property lookup most likely).  Valid types
    # are:
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
    } else {
	$dataref = $self->_scalar_xml( $data );	
    }
        
    my @rid = ();
    @rid = ( requestid => $requestid ) if defined $requestid;
    return $self->xmlout( reply => { @rid, %$statusref, %$dataref } );    
}

sub _entity_xml {
    my ($self, $entity) = @_;

    my ($name, $start, $stop) = ($entity->name(), $entity->start(), $entity->stop() || '');
    my ($startinfo) = $entity->yggdrasil()->get_ticks( $start );
    my ($stopinfo) = $entity->yggdrasil()->get_ticks( $stop ) if $stop;    

    $stopinfo  = $stopinfo->{stamp} || '';
    $startinfo = $startinfo->{stamp};

    return { entity => {
			name => $name,
			start => $start,
			stop => $stop,
			starttime => $startinfo,
			stoptime => $stopinfo
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

1;
