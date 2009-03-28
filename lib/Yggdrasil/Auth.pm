package Yggdrasil::Auth;

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);

use base qw(Yggdrasil::Object);

use Yggdrasil::Role;
use Yggdrasil::User;
use Yggdrasil::Debug qw|debug_if debug_level|;

sub authenticate {
    my $self = shift;
    my %params = @_;
    
    my ($user, $pass, $session) = ($params{'user'}, $params{'pass'}, $params{'session'});

    my $status = $self->get_status();
    my $authentity = $self->{yggdrasil}->get_entity( 'MetaAuthUser' );
    
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
	$self->{user} = $user;
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
	$self->{user} = $user;
	return $self->{session};	
    }

    return;
}

# TODO: Sanitycheck $operator, make property-compatible.
sub can {
    my $self = shift;
    my %params = @_;
    
    my $ygg       = $self->{yggdrasil};
    my $target    = $params{target};
    my $operation = $params{operation};
    my $storage   = $ygg->{storage};
    my $user      = $ygg->{user} || '';

    my $dataref   = $params{data};

    my @targets_to_check;

    return 1 if $target =~ /:/; # properties not implemented.

    my $roleid_of_user;
    if ($user) {
	$roleid_of_user = $self->_get_user_role( $user );
	debug_if( 4, "Roleid is $roleid_of_user." );
    }
    
    # If we wish to write to MetaEntity, we have in reality asked to
    # create an entity.  To be allowed to do this we have to ask if we
    # are allowed to subclass the entity in question, which is a 'w'
    # operation.  We might wish to have a "subclass" bit.
    if ($target eq 'MetaEntity' && $operation eq 'store') {
	for my $t ($self->_get_metaentity_store_targets( $dataref )) {
	    push @targets_to_check, $storage->parent_of( $t );
	}
	$operation = 'writeable';
    } elsif ($target eq 'MetaProperty' && $operation eq 'store') {
	for my $t ($self->_get_metaproperty_store_targets( $dataref )) {
	    push @targets_to_check, $storage->parent_of( $t );
	}
	$operation = 'writeable';
    } elsif ($target eq 'Entities' && $operation eq 'store') {
	for my $t ($self->_get_metaentity_store_targets( $dataref )) {
	    push @targets_to_check, $storage->parent_of( $t );
	}
	$operation = 'createable';
    } elsif ($target eq 'MetaInheritance') {
	push @targets_to_check, $self->_get_inheritance_parent( $dataref );
	$operation = 'writeable';
    } elsif ($target eq 'MetaRelation') {
	push @targets_to_check, $self->_get_relation_targets( $dataref );
	$operation = 'writeable';
    } elsif ($operation eq 'define') {
	push @targets_to_check, $target;
	$operation = 'writeable';
    } elsif ($target =~ '^Storage_') {
	return 1;
    } elsif ($operation eq 'read') {
	for my $t (@$target) {
	    print "$t\n";
	    push @targets_to_check, $t;
	}
    } elsif ($target eq 'MetaAuthEntity') { # FIXME, check parents.
	return 1;
    } else {
	if( $operation =~ /^c/ ) {
	    $operation = 'createable';
	} elsif ($operation =~ /^d/) {
	    $operation = 'deleteable';
	} elsif ($operation =~ /^w/) {
	    $operation = 'writeable';
	} elsif ($operation =~ /^r/) {
	    $operation = 'readable';
	} else {
	    return undef;
	}
    }
	  
    #	debug_if( 4, "Requested check of $operation on $target for $user..." );
    for my $entity (@targets_to_check) {
	return 1 if $operation eq 'readable' && $self->_global_read_access( $entity );
       
	debug_if( 4, "Checking $operation on $entity for $user..." );
	my $permission = $self->_can( $roleid_of_user, $entity, $operation );
# 	my $idfetch = $storage->fetch(
# 				      MetaEntity => { where => [ entity    => $entity ] },
# 				      Entities   => { where => [
# 								visual_id => $user,
# 								entity    => \qq{MetaEntity.id}
# 							       ] },
# 				      MetaAuthRolemembership => { where => [ user   => \qq{Entities.id} ] },
# 				      MetaAuthEntity         => {
# 								 where => [
# 									   entity => \qq{MetaEntity.id},
# 									   role   => \qq{MetaAuthRolemembership.role},
# 									  ],
# 								 return => $operation,
# 								},
    
	return unless $permission;
    }
    return 1;
}

sub _setup_default_users_and_roles {
    my $self = bless {}, shift;
    my %params = @_;
    $self->{yggdrasil} = $params{yggdrasil};
    
    my( $adminrole, $userrole ) = $self->_generate_default_roles( @_ );
    my @users = $self->_generate_default_users( @_ );

    # both users 'root' and '$>' are admins.
    for my $user (@users) {
	$adminrole->add($user);	 
    }
    return @users;
}

sub _generate_default_roles {
    my $self = shift;
    my %params = @_;
    my $ygg = $params{yggdrasil};
    
    my @roles;
    for my $r ( "admin", "user" ) {
	my $role = Yggdrasil::Role->define( yggdrasil => $self, role => $r );

	if ($r eq 'admin') {
	    $role->grant( 'UNIVERSAL', 'd' );
	    $role->grant( 'MetaAuthUser', 'd' );
	    $role->grant( 'MetaAuthRole', 'd' );
	} else {
	    $role->grant( 'UNIVERSAL', 'r' );
	    $role->grant( 'MetaAuthUser', 'r' );
	    $role->grant( 'MetaAuthRole', 'r' );
	}
	push( @roles, $role );
    }

    return @roles;
}

sub _generate_default_users {
    my $self = shift;
    my %params = @_;
    my $ygg  = $params{yggdrasil};

    my %requested_users = %{$params{users}};
    my @users;
    
    for my $u ( "root", (getpwuid( $> ) || "default"), keys %requested_users ) {
	my $user = Yggdrasil::User->define( yggdrasil => $self, user => $u, password => $requested_users{$u} || _generate_password() );

	push( @users, $user );
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

sub _get_user_role {
    my $self = shift;
    my $user = shift;

    # To avoid recursion, call _fetch directly.  :-/
    my $ref = $self->{yggdrasil}->{storage}->_fetch( 
						    MetaAuthRolemembership => { where => [ user => \qq{Entities.id} ],
										return => 'role' },
						    Entities     => { where => [ visual_id => $user ]}
						   );

    return $ref->[0]->{role};
}

sub _can {
    my $self = shift;
    my $role = shift;
    my $entity = shift;
    my $operation = shift;

    my $ref;
    if ($entity =~ /^\d+/) {
	$ref = $self->{yggdrasil}->{storage}->_fetch( 
						    MetaAuthEntity => { where  => [ role   => $role,
									            entity => $entity ],
									return => $operation },
						   );
    } else {
	$ref = $self->{yggdrasil}->{storage}->_fetch( 
						    MetaAuthEntity => { where => [ role => $role ],
									return => $operation },
						    MetaEntity     => { where => [
										  id => \qq{MetaAuthEntity.entity},
										  entity => $entity,
										 ]},
						   );
    }

    return $ref->[0]->{$operation};
}

sub _get_read_targets {
    my ($self, $dataref) = @_;
    return keys %{$dataref};
}

sub _get_metaentity_store_targets {
    my ($self, $dataref) = @_;
    return values %{$dataref->{fields}};
}

sub _get_metaproperty_store_targets {
    my ($self, $dataref) = @_;
    return $dataref->{fields}->{entity}
}

sub _get_relation_targets {
    my ($self, $dataref) = @_;
    return ($dataref->{fields}->{rval}, $dataref->{fields}->{lval});
}

sub _get_inheritance_parent {
    my ($self, $dataref) = @_;
    return ($dataref->{fields}->{parent}, $dataref->{fields}->{child});
}

sub _global_read_access {
    my ($self, $entity) = @_;

    if ($entity =~ /^Storage/ || $entity =~ /Meta/ || $entity eq 'Entities') {
	return 1;
    } else {
	return 0;
    }
}

1;
