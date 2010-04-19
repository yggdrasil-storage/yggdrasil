package POE::Component::Server::Yggdrasil::Interface;

use warnings;
use strict;

use XML::Simple;
use POE::Component::Server::Yggdrasil::Interface::Commands;
use POE::Component::Server::Yggdrasil::Interface::XML;

sub new {
    my $class = shift;
    my %params = @_;

    my $self = {};
    $self->{client}   = $params{client};
    $self->{commands} = new POE::Component::Server::Yggdrasil::Interface::Commands(
				      yggdrasil => $params{client}->{yggdrasil} );
    $self->{xml} = new POE::Component::Server::Yggdrasil::Interface::XML;
    
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

    my @retobjs;
    for my $request (keys %$ref) {
	my $root = $ref->{request};

	my $command = delete $root->{exec};
	unless ($self->{commands}->{$command}) {
	    push @retobjs, $self->{xml}->xmlify_status( 406, "Unknown command '$command'" );
	    next;
	}
	
	my $callback = $self->{commands}->{$command};
	
	my @args;
	push @args, delete $root->{id} if $root->{id};
	@args = map { $_ => $root->{$_} } keys %$root unless @args;
	
	my $ret = $callback->( @args );	
	my $status = $self->{client}->{yggdrasil}->get_status();
	
	if ($status->OK()) {
	    push @retobjs, $self->{xml}->xmlify( $status, $ret );
	} else {
	    push @retobjs, $self->{xml}->xmlify( $status );
	}
    }
    
    return "<yggdrasil>\n" . join( "\n", @retobjs ) . "</yggdrasil>\n";    
}

1;
