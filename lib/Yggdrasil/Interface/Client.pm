package Yggdrasil::Interface::Client;

use warnings;
use strict;

use IO::Socket::SSL;

sub new {
    my $class = shift;
    my %params = @_;
    
    my $self = bless {}, $class;

    $self->{yggdrasil} = $params{yggdrasil};
    $self->_populate_protocols();    
    
    return $self;
}

sub connect {
    my $self = shift;
    my %params = @_;
    
    my $client = IO::Socket::SSL->new(
				      PeerAddr => $params{'daemonhost'},
				      PeerPort => $params{'daemonport'},
				     );
    my $status = $self->get_status();

    if ($client) {
	$self->{connection} = $client;
	$status->set( 200, "Successfully connected to $params{daemonhost}:$params{daemonport}" );
    } else {
	$status->set( 400, "Unable to connect to $params{daemonhost}:$params{daemonport} (" . 
		      IO::Socket::SSL::errstr() . ")" );
    }
    return $client;
}

sub login {
    my $self = shift;
    my %params = @_;
    my $status = $self->get_status();

    my $con = $self->{connection};
    print $con "username: $params{username}\n";
    print $con "password: $params{password}\n";    
    $self->_parse_client_line_reply( $con );

    if ($status->OK()) {
	$self->enable_protocol( $con, $params{protocol} );
	return $params{username} if $status->OK();
    }
    return undef;
}

sub protocols {
    my $self = shift;

    return sort keys %{$self->{protocols}};
}

sub enable_protocol {
    my $self          = shift;
    my $connection    = shift;
    my $protocol_name = shift;

    my $status = $self->get_status();
    my $protocol_exists = $self->{protocols}->{$protocol_name};
    
    if ($protocol_exists) {
	my $protocol_class = join("::", __PACKAGE__, $protocol_name );
	eval qq( require $protocol_class );
	if ($@) {
	    $status->set( 500, "Unable to load '$protocol_name': $@" );
	    return;
	}
	$self->{protocol} = $protocol_class->new( yggdrasil => $self->yggdrasil(),
						  stream    => $self->{connection} );
	print $connection "protocol: xml\n";
	$self->_parse_client_line_reply( $connection );
	return $self->{protocol} if $status->OK();
    } else {
	$status->set( 400, "No protocol '$protocol_name' defined, unable to load" );
	return undef;
    }
}

sub _populate_protocols {
    my $self = shift;
    my $path = join '/', $self->_client_path();
    my $status = $self->get_status();

    if (opendir( my $dh, $path )) {
	for my $p (readdir $dh) {
	    next if -d $p;
	    next unless $p =~ s/\.pm$//;
	    $self->{protocols}->{$p} = 1;
	}
	closedir $dh;
    } else {
	$status->set( 503, "Unable to find any protocols defined under $path: $!");
	return undef;
    }
}

sub _client_path {
    my $self = shift;
    
    my $file = join('.', join('/', split '::', __PACKAGE__), "pm" );
    my $path = $INC{$file};
    $path =~ s/\.pm$//;
    return $path;
}

sub _parse_client_line_reply {
    my $self = shift;
    my $con  = shift;
    my $status = $self->get_status();
    
    my $server_reply = <$con>;
    my ($ss, $sm) = split /\s*,\s*/, $server_reply, 2;
 
    $status->set( $ss, $sm );
}


sub yggdrasil {
    my $self = shift;
    return $self->{yggdrasil};
}

sub get_status {
    my $self = shift;
    return $self->{yggdrasil}->get_status();
}

1;
