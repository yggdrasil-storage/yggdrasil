package Yggdrasil::Auth;

use strict;
use warnings;

use base qw(Yggdrasil::MetaAuth);

use Yggdrasil::Auth::Role;

sub define {
    my $class = shift;
    my %params = @_;

    if( exists $params{role} ) {
	return _define_role( $params{role} );
    } elsif( exists $params{user} && exists $params{password} ) {
	return _define_user( $params{user}, $params{password} );
    } else {
	# be angry
    }
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

    for my $user (@users) {
	if( $user->id() eq "root" ) {
	    $adminrole->add($user);
	} else {
	    $userrole->add($user);
	}
    }
}

sub _generate_default_roles {
    my @roles;
    for my $r ( "admin", "user" ) {
	my $role = __PACKAGE__->define( role => $r );
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
