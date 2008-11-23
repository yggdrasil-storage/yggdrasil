package Yggdrasil::Plugin::Auth;

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);

use base qw(Yggdrasil::Plugin::Shared);

sub authenticate {
    my $self = shift;
    my %params = @_;

    my $user = $params{user};
    my $pass = $params{pass};

    my $package = join("::", $self->{namespace}, $self->{entity});
    if( defined $user && defined $pass ) {
	my $instance = $package->get( $user );

	return unless $instance;
	
	my $userpass = $instance->property("password");
	return unless defined $userpass;
	return unless $pass eq $userpass;

	my $sid = md5_hex(time() * $$ * rand(time() + $$));
	$self->{session} = $sid;
	$self->{user} = $instance;

	$instance->property( session => $sid );

	return $self->{session};
    }


    my $session = $params{session};

    if( $session ) {
	my @hits = $package->search( session => $session );
	return if @hits != 1;

	$self->{session} = $session;
	$self->{user} = $package->get( $hits[0]->id() );

	return $self->{session};
    }
     

    return;
}


sub instance {
    my $self = shift;
    my $entity = shift;
    my $ident = shift;

    my @p = $self->SUPER::instance($entity, $ident);

    my @v;
    foreach my $prop ( @p ) {
	# --- XXX: remove me --- test
	next if $prop->{property} eq "department";


	# --- XXX: remove me --- test
	if( $prop->{property} eq "ip" || $prop->{property} eq "position" ) {
	    $prop->{access} = "write";
	}

	push( @v, $prop );
    }

    return @v;
}

sub related {
    my $self = shift;
    my $entity = shift;
    my $ident = shift;


    my @p = $self->SUPER::related( $entity, $ident );

    my @v;
    foreach my $e ( @p ) {
	next if $e->{_id} eq $entity;

	push( @v, $e );
    }

    return @p;
}

1;
