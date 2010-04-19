package POE::Component::Server::Yggdrasil::Interface::XML;

use warnings;
use strict;

sub new {
    my $class = shift;
    return bless {}, $class;
}

sub xmlify {
    my ($self, $status, $data) = @_;

    my $statusxml = $self->_status_xml( $status );
    return $statusxml unless $data;

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
    
    my $dataxml;
    if (ref $data eq 'Yggdrasil::Entity') {
	$dataxml = $self->_entity_xml( $data );
    } elsif (ref $data eq 'Yggdrasil::Entity::Instance') {
	$dataxml = $self->_instance_xml( $data );	
    } elsif (ref $data eq 'Yggdrasil::Property') {
	$dataxml = $self->_property_xml( $data );	
    } elsif (ref $data eq 'Yggdrasil::Relation') {
	$dataxml = $self->_relation_xml( $data );	
    } elsif (ref $data) {
	# Unknown data reference, that's not good.
	$dataxml = $self->xmlify_status( 406, "Unknown data type ($data) passed to XML backend" );
    } else {
	$dataxml = $self->_scalar_xml( $data );	
    }
    
    return " <reply>$statusxml\n$dataxml </reply>\n";
}

sub _entity_xml {
    my ($self, $entity) = @_;

    my ($name, $start, $stop) = ($entity->name(), $entity->start(), $entity->stop() || '');
    my ($startinfo) = $entity->yggdrasil()->get_ticks( $start );
    my ($stopinfo) = $entity->yggdrasil()->get_ticks( $stop ) if $stop;    

    $stopinfo  = $stopinfo->{stamp} || '';
    $startinfo = $startinfo->{stamp};
    
    return "  <entity>
   <name>$name</name>
   <start>$start</start>
   <stop>$stop</stop>
   <starttime>$startinfo</starttime>
   <stoptime>$stopinfo</stoptime>
  </entity>\n";
}


sub _status_xml {
    my ($self, $status) = @_;
    return $self->xmlify_status( $status->status(), $status->message());
}

sub xmlify_status {
    my ($self, $retval, $retstr) = @_;
    return "
  <status>
   <code>$retval</code>
   <message>$retstr</message>
  </status>
";

}

1;
