package Yggdrasil::Remote::Client;

use warnings;
use strict;

use IO::Socket::SSL;
use Storage::Debug;

sub new {
    my $class = shift;
    my %params = @_;
    
    my $self = bless {}, $class;

    $self->{status} = $params{status};
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
	my $server_reply = '';
	while (1) {
	    $server_reply = <$client>;
	    last if $server_reply =~ /^OK/;
	    chomp $server_reply;
	    push @{$self->{server_data}}, $server_reply;
	}
	$self->{connection}  = $client;
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

sub server_data {
    my $self = shift;
    return @{$self->{server_data}};
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
	    $status->set( 500, "Unable to load the requested protocol '$protocol_name':\n$@" );
	    return;
	}
	$self->{protocol} = $protocol_class->new( status => $self->get_status(),
						  stream => $self->{connection} );
	print $connection "protocol: $protocol_name\n";
	$self->_parse_client_line_reply( $connection );
	return $self->{protocol} if $status->OK();
    } else {
	$status->set( 400, "No protocol '$protocol_name' defined, unable to load" );
	return undef;
    }
}

sub debugger {
    my $self = shift;
    $self->{debug} ||= new Storage::Debug;
    
    return $self->{debug};
}

sub debug {
    my $self = shift;
    my $key  = shift;

    if (@_) {
	my $value = shift;
	$self->debugger()->set( $key, $value );
    }
    
    return $self->debugger()->get( $key );
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
    $sm =~ s/\r\n$//g;

    $status->set( $ss, $sm );
}


sub get_status {
    my $self = shift;
    return $self->{status};
}

sub can {
    my $self = shift;
    return $self->{protocol}->can( @_ );
}

1;
