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
    # can rightfully assume it's an Yggdrasil object, a simple scalar
    # containing a value (property lookup most likely) or a list of
    # values (list of usernames etc).  Valid types are:
    #
    #  * Entities   (Yggdrasil::Entity)
    #  * Instances  (Yggdrasil::Instance)
    #  * Properties (Yggdrasil::Property)
    #  * Relations  (Yggdrasil::Relation)
    #  * Users      (Yggdrasil::User)
    #  * Roles      (Yggdrasil::Role)
    #  * <$scalar>  (Value, encode if needed and return)
    #  * arrayref   (Values)
    
    my %data;
    $data = [ $data ] unless ref $data eq 'ARRAY';

    for my $entry (@$data) {
	my ($key, $val) = $self->_create_xml_chunk( $entry );
	return $self->generate_status_reply( $requestid, 406, "Unknown data type ($data) passed to XML backend" )
	  unless $val;
	push @{$data{$key}}, $val;
    }
    
    my @rid = ();
    @rid = ( requestid => $requestid ) if defined $requestid;

    use Data::Dumper;
    print Dumper( \%data );
    
    return $self->xmlout( reply => { @rid, %$statusref, %data } );
}

sub _create_xml_chunk {
    my $self = shift;
    my $data = shift;
    
    if (ref $data) {
	if ($data->isa( 'Yggdrasil::Entity' )) {
	    return $self->_entity_xml( $data );
	} elsif ($data->isa( 'Yggdrasil::Instance' )) {
	    return $self->_instance_xml( $data );	
	} elsif ($data->isa( 'Yggdrasil::Property' )) {
	    return $self->_property_xml( $data );
	} elsif ($data->isa( 'Yggdrasil::Relation' )) {
	    return $self->_relation_xml( $data );	
	} elsif ($data->isa( 'Yggdrasil::User' )) {
	    return $self->_user_or_role_xml( $data );	
	} elsif ($data->isa( 'Yggdrasil::Role' )) {
	    return $self->_user_or_role_xml( $data );
	} else {
	    # Unknown data reference, that's not good.
	    return undef;
	}
    } elsif ($data) {
	return $self->_scalar_xml( $data );	
    }
    return undef;
}

sub _entity_xml {
    my ($self, $entity) = @_;

    my $name = $entity->name();
    my ($start, $stop, $starttime, $stoptime) = $self->_get_times( $entity );
    
    return entity => {
		      id => $name,
		      start => $start,
		      stop => $stop,
		      starttime => $starttime,
		      stoptime => $stoptime,
		     };
    
}

sub _property_xml {
    my ($self, $property) = @_;
    
    my $name = $property->name();
    my ($start, $stop, $starttime, $stoptime) = $self->_get_times( $property );

    return property => {
			id => $name,
			entity => $property->entity()->name(),
			start => $start,
			stop => $stop,
			starttime => $starttime,
			stoptime => $stoptime,
		       };
    
}

sub _instance_xml {
    my ($self, $instance) = @_;
    
    my $name = $instance->id();
    my ($start, $stop, $starttime, $stoptime) = $self->_get_times( $instance );

    return instance => {
			id => $name,
			entity => $instance->entity()->name(),
			start => $start,
			stop => $stop,
			starttime => $starttime,
			stoptime => $stoptime,
		       };
    
}

sub _relation_xml {
    my ($self, $relation) = @_;
    
    my $name = $relation->label();
    my ($start, $stop, $starttime, $stoptime) = $self->_get_times( $relation );
    my ($lval, $rval) = $relation->entities();
    
    return relation => {
			id => $name,
			label => $name,
			lval => $lval->name(),
			rval => $rval->name(),
			start => $start,
			stop => $stop,
			starttime => $starttime,
			stoptime => $stoptime,
		       };
    
}


sub _scalar_xml {
    my ($self, $value, $object) = @_;
    
    # We could use the object, an instance, to check the type of the
    # property and then do the right thing[tm] with the value.  We
    # might wish to base64 a few types, but for now, just pass it
    # through as is.
    return value => $value;
    
}

sub _user_or_role_xml {
    my ($self, $obj) = @_;

    my $name = $obj->id();
    my $class = $obj->isa( 'Yggdrasil::User' )?'user':'role';
    my ($start, $stop, $starttime, $stoptime) = $self->_get_times( $obj );
    
    return $class => {
		      id => $name,
		      start => $start,
		      stop => $stop,
		      starttime => $starttime,
		      stoptime => $stoptime,
		     };
}

sub _status_xml {
    my ($self, $status) = @_;
    return $self->xmlify_status( $status->status(), $status->message());
}

sub xmlify_status {
    my ($self, $retval, $retstr) = @_;
    return { status => { code => $retval, message => $retstr }};
}

sub xmlout {
    my $self = shift;
    
    return XMLout( { @_ }, NoAttr => 1, KeyAttr => [], RootName => undef );
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
    
#    print "$start $stop $starttime $stoptime\n";
    
    return ($start, $stop, $starttime, $stoptime);
}

1;
