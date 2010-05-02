package POE::Component::Server::Yggdrasil;

use warnings;
use strict;

use Carp;
use IO::Socket::INET; # For constants

use FindBin qw($Bin);

use lib qw|$Bin/../lib|;

use Yggdrasil;

use POE qw( Wheel::SocketFactory Wheel::ReadWrite Filter::XML Filter::Line Driver::SysRW );
use POE::Filter::XML::Node;
use POE::Component::SSLify qw( Server_SSLify SSLify_Options );

use POE::Component::Server::Yggdrasil::Interface;

our $VERSION = '0.03';

sub spawn {
    my $package = shift;
    confess "Uneven parameter list" if @_ % 2;
    my %params = @_;

    my $self = bless {}, $package;

    my $etc = "$Bin/../etc";

    eval { SSLify_Options( "$etc/server.key", "$etc/server.crt" ) };
    if ( $@ ) {
	print "Unable to load SSL certificates, $@\n";
	$self->{ssl} = 0;
    } else {
	$self->{ssl} = 1;
    }

    my %yggcache;
    $self->{alias}     = defined $params{alias} || 'Yggdrasil Daemon v.X';
    $self->{port}      = $params{port} || 59999;
    $self->{address}   = $params{address} || 'localhost';
    $self->{startup}   = time;
    $self->{yggcache}  = \%yggcache;
    
    $self->{engineuser}     = $params{euser};
    $self->{enginepassword} = $params{epassword};
    $self->{enginehost}     = $params{ehost};
    $self->{engineport}     = $params{eport};
    $self->{enginedb}       = $params{edb};
    $self->{enginetype}     = $params{eengine};

    $self->{supported_protocol}->{xml} = POE::Filter::XML->new( 'NOTSTREAMING' => 1 );
    
    POE::Session->create(
			 object_states => [
			   $self => { 
				    _start   => '_server_start',
				    _stop    => '_server_stop',
				    shutdown => '_server_close',
				   },
			   $self => [
				     qw(
					   _accept_new_client
					   _accept_failed
					   _client_input
					   _client_error
				      ),
				    ],
			  ],
			);
    return $self;
}

sub preamble {
    my ($server, $client) = @_;
    my $protos = join ', ', sort keys %{$server->{supported_protocol}};
    return "Server version: $VERSION
Yggdrasil version: $Yggdrasil::VERSION
Available protocols: $protos
OK";
}

sub _server_start {
    my ($kernel, $self) = @_[KERNEL,OBJECT];
    $kernel->alias_set( $self->{alias} );

    $self->{Listener} =
      POE::Wheel::SocketFactory->new(
	BindPort       => $self->{port},
	BindAddress    => $self->{address},
	SuccessEvent   => '_accept_new_client',
	FailureEvent   => '_accept_failed',
	SocketDomain   => AF_INET,
	SocketType     => SOCK_STREAM,
	SocketProtocol => 'tcp',
	Reuse          => 'on',
    );
}

sub _server_stop {
    my ($kernel, $self) = @_[KERNEL,OBJECT];
    print "Server exited\n";
}

sub _server_close {
    my ($kernel, $self) = @_[KERNEL,OBJECT];

    delete $self->{Listener};
    delete $self->{Clients};
    $kernel->alias_remove( $self->{alias} );
}

sub _accept_new_client {
    my ($kernel, $self, $socket, $peeraddr, $peerport) = @_[KERNEL,OBJECT,ARG0 .. ARG2];
    $peeraddr = inet_ntoa( $peeraddr );

    if ($self->{ssl}) {
	eval { $socket = Server_SSLify( $socket ) };
	if ( $@ ) {
	    print "Unable to SSL socket! $@\n";
	}
    }
    
    my $wheel = POE::Wheel::ReadWrite->new(
	   Handle => $socket,
           Filter => POE::Filter::Line->new(),					   
           InputEvent => '_client_input',
           ErrorEvent => '_client_error',
    );

    $wheel->put( $self->preamble() );
    my $wheel_id = $wheel->ID();
    $self->{Clients}->{ $wheel_id }->{yggcache} = $self->{yggcache};
    $self->{Clients}->{ $wheel_id }->{clientstart} = time;
    $self->{Clients}->{ $wheel_id }->{Wheel} = $wheel;
    $self->{Clients}->{ $wheel_id }->{peeraddr} = $peeraddr;
    $self->{Clients}->{ $wheel_id }->{peerport} = $peerport;
}

sub _accept_failed {
    my ($kernel, $self) = @_[KERNEL,OBJECT];
    warn "Unable to accept, socket busy?\n";
    $kernel->yield( 'shutdown' );
}

sub _client_input {
    my ($kernel, $self, $input, $wheel_id) = @_[KERNEL,OBJECT,ARG0,ARG1];

    confess "No wheel ID" unless $self->{Clients}->{$wheel_id};
    confess "No wheel for $wheel_id" unless $self->{Clients}->{$wheel_id}->{Wheel};

    my $client = $self->{Clients}->{$wheel_id};
    # If we haven't set a protocol yet, expect it to be issued.
    unless ($client->{protocol}) {
	_handle_line_input( $self, $client, $input );
	return;
    }

    my $return = $client->{interface}->process(
					       mode   => $client->{protocol},
					       data   => $input->toString(),
					       client => $client,
					      );
    $client->{Wheel}->put( $return );
}

sub _handle_line_input {
    my ($server, $client, $input) = @_;
    
    if ($input =~ /^protocol: (\w+)$/i) {
	my $protocol_format = lc $1;
	if ($client->{authenticated}) {
	    if ($server->{supported_protocol}->{$protocol_format}) {
		$client->{Wheel}->set_input_filter( $server->{supported_protocol}->{$protocol_format} );

		# Do protocol specific setup here.
		if ($protocol_format eq 'xml') {
		    $server->{supported_protocol}->{$protocol_format}->callback( sub { &_parsing_error( $client ) } );
		}

	    } else {		
		$client->{Wheel}->put( "406, Unsupported protocol '$protocol_format' requested" );
		return;
	    }

	    my $interface = new POE::Component::Server::Yggdrasil::Interface( client   => $client,
									      protocol => $protocol_format );
	    $client->{protocol} = $protocol_format;
	    $client->{interface} = $interface;
	    $client->{Wheel}->put( '200, Switching to ' . $protocol_format );
	} else {
	    $client->{Wheel}->put( '400, Please authenticate before switching protocols' );
	}
    } elsif ($input =~ /username: (\w+)/) {
	$client->{username} = $1;
    } elsif ($input =~ /password: (\w+)/) {
	$client->{password} = $1;
    } else {
	$client->{Wheel}->put( '400, Unknown command' );	
    }

    if (! $client->{authenticated} && $client->{username} && $client->{password}) {
	my $y = new Yggdrasil;
	my $s = $y->get_status();
	$y->connect( 
		    user      => $server->{engineuser},
		    password  => $server->{enginepassword},
		    host      => $server->{enginehost},
		    port      => $server->{engineport},
		    db        => $server->{enginedb},
		    engine    => $server->{enginetype},
		    cache     => $server->{yggcache},
		   );

	if ($s->OK()) {
	    my $iam = $y->login( username => $client->{username}, password => $client->{password});    
	    if ($s->OK()) {
		$client->{authenticated} = $iam;
		$client->{password} = undef;
		$client->{yggdrasil} = $y;
		$client->{Wheel}->put( $s->status() . ", Welcome to yggdrasil '"  . $client->{username} . "'" );

		$client->{whoami} = "Connecting from " . $client->{peeraddr} . ":" . $client->{peerport} .
		  " to " . $server->{address} . ':' . $server->{port} . " as " . $client->{username} ;
		$client->{serverstart} = $server->{startup};
	    } else {
		$client->{Wheel}->put( $s->status() . ', ' . $s->message() );	
	    }
	} else {
	    $client->{Wheel}->put( $s->status() . ", " . $s->message() );
	}
    }
    return undef;
}

sub _client_error {
    my ($self, $wheel_id) = @_[OBJECT,ARG3];
    delete $self->{Clients}->{$wheel_id};
}

sub _parsing_error {
    my $client = shift;
    delete $client->{Wheel};
}

1;
