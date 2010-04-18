package POE::Component::Server::Yggdrasil::Interface;

use warnings;
use strict;

use XML::Simple;
use POE::Component::Server::Yggdrasil::Interface::Commands;

sub new {
    my $class = shift;
    my %params = @_;

    my $self = {};
    $self->{client}   = $params{client};
    $self->{commands} = new POE::Component::Server::Yggdrasil::Interface::Commands(
				      yggdrasil => $params{client}->{yggdrasil} );
    
    return bless $self, $class;
}

sub process {
    my $self = shift;
    my %params = @_;
    my $mode = $params{mode};
    my $data = $params{data};
    
    if ($mode eq 'xml') {
	return $self->_process_xml( $data );
    } else {
	# Unsupported mode, scary stuff, how do we know what to
	# return?  We don't, so we return undef.  The caller will have
	# to handle this gracefully, it has accepted the mode /
	# protocol at some point, so it should know what to do with
	# it.
	return;
    }    
}

sub _process_xml {
    my $self = shift;
    my $xml  = shift;

    my $ref = XMLin( $xml );

    use Data::Dumper;
    print Dumper( $ref );
    
    my $root = $ref->{yggdrasil};
    if ($root) {
	my $commandname = delete $root->{command};
	unless ($self->{commands}->{$commandname}) {
	    return $self->_return_xml( 400, "No command '$commandname'" );
	}

	my $callback = $self->{commands}->{$commandname};

	my @args;
	push @args, delete $root->{id} if $root->{id};
	@args = map { $_ => $root->{$_} } keys %$root unless @args;

	my $ret = $callback->( @args );	

	my $status = $self->{client}->{yggdrasil}->get_status();
	
	if ($status->OK()) {
	    my $stop = $ret->stop() || '';
	    # We need a way to XMLify the object.
	    return "<yggdrasil>
 <entity>
  <name>" . $ret->name() . "</name>
  <start>" . $ret->start() . "</start>
  <stop>$stop</stop>
  <instances>" . join(", ", $ret->instances()) . "</instances>
 </entity>
</yggdrasil>\n";
	} else {
	    return $self->_return_xml( $status->status(), $status->message() );
	}
	


	return "XMLFIY: $ret";
    } else {
	return $self->_return_xml( 406, 'Missing root element' );
    }
}

sub _return_xml {
    my ($self, $retval, $retstr) = @_;
    return "<yggdrasil>
 <status>
  <code>$retval</code>
  <message>$retstr</message>
 </status>
</yggdrasil>
";
}

1;
