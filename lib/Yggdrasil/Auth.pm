package Yggdrasil::Auth;

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);

use base qw(Yggdrasil::MetaAuth);

use Yggdrasil::Auth::Role;
use Yggdrasil::Status;

sub _define {
    my $self = shift;
    my %params = @_;

    if( exists $params{role} ) {
	return _define_role( $params{role} );
    } elsif( exists $params{user} && exists $params{password} ) {
	return _define_user( $params{user}, $params{password} );
    } else {
	# be angry
    }
    return $self;
}

sub authenticate {
    my $self = shift;
    my %params = @_;
    
    my ($user, $pass, $session) = ($params{'user'}, $params{'pass'}, $params{'session'});

    my $status = new Yggdrasil::Status;
    my $authentity = $self->get_entity( 'MetaAuthUser' );
    
    # First, let see if we're connected to a tty without getting a
    # username / password, at which point we're already authenticated
    # and we don't want to touch the session.  $> is effective UID.
    if (-t && ! defined $user && ! defined $pass) {
	$self->{user} = (getpwuid($>))[0];
	$status->set( 200 );
	return 1;
    } 

    # Otherwise, we got both a username and a password.
    if (defined $user && defined $pass) {
	my $userobject = $authentity->fetch( $params{user} );

	unless ($userobject) {
	    $status->set( 403 );
	    return;
	}
	
	my $realpass = $userobject->property( 'password' ) || '';

	if (! defined $pass || $pass ne $realpass) {
	    $status->set( 403 );
	    return;
	}
	
	my $sid = md5_hex(time() * $$ * rand(time() + $$));
	$self->{session} = $sid;
	$userobject->property( 'session', $sid );
	$status->set( 200 );
	return $sid;
    } elsif ($session) {
	my @hits = $authentity->search( session => $session );

	if (@hits != 1) {
	    $status->set( 403 );
	    return;
	}

	$self->{session} = $session;
	$self->{user} = $authentity->get( $hits[0]->id() );

	$status->set( 200 );
	return $self->{session};
    }

    return;
}

sub _define_role {
    my $role = shift;

    my $meta_role = get Yggdrasil::Entity 'MetaAuthRole';
    return bless $meta_role->new( $role ), 'Yggdrasil::Auth::Role';
}

sub _define_user {
    my $user = shift;
    my $pass = shift;

    my $meta_user = get Yggdrasil::Entity 'MetaAuthUser';
    my $uo = $meta_user->new( $user );
    $uo->property( password => $pass );

    return $uo;
}

sub _setup_default_users_and_roles {
    my( $adminrole, $userrole ) = Yggdrasil::Auth->_generate_default_roles();
    my @users = Yggdrasil::Auth->_generate_default_users();

    # both users 'root' and '$>' are admins.
    for my $user (@users) {
	$adminrole->add($user);	    
    }
}

sub _generate_default_roles {
    my @roles;
    for my $r ( "admin", "user" ) {
	my $role = __PACKAGE__->define( role => $r );

	if ($r eq 'admin') {
	    $role->grant( 'UNIVERSAL', 'd' );
	} else {
	    $role->grant( 'UNIVERSAL', 'r' );
	}
	 
	push( @roles, $role );
    }

    return @roles;
}

sub _generate_default_users {
    my @users;
    for my $u ( "root", (getpwuid( $> ) || "default") ) {
	my $meta_user = get Yggdrasil::Entity 'MetaAuthUser';
	my $user = $meta_user->get( $u );
	next if $user;

	my $pass = _generate_password();
	my $uo = __PACKAGE__->define( user => $u, password => $pass );
	push( @users, $uo );
    }

    return @users;
}

sub _generate_password {
    my $randomdevice = "/dev/urandom";
    my $pwd_length = 12;
    
    my $password = "";
    my $randdev;
    open( $randdev, $randomdevice ) 
	|| die "Unable to open random device $randdev: $!\n";
    until( length($password) == $pwd_length ) {
        my $byte = getc $randdev;
        $password .= $byte if $byte =~ /[a-z0-9]/i;
    }
    close $randdev;

    return $password;
}

1;
