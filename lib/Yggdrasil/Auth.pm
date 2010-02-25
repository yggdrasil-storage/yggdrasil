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
    
    my ($user, $pass, $session) = ($params{'user'}, $params{'password'}, $params{'session'});

    my $status = $self->get_status();
    #my $authentity = $self->{yggdrasil}->get_entity( 'MetaAuthUser' );

    my $user_obj;

    if (defined $user && defined $pass) {
	# Otherwise, we got both a username and a password.
	$user_obj = Yggdrasil::User->get( yggdrasil => $self, user => $user );

	if( $user_obj ) {
	    my $realpass = $user_obj->password() || '';

	    if (! defined $pass || $pass ne $realpass) {
		$user_obj = undef;
	    }
	}
	$session = undef;
    } elsif ($session) {
	# Lastly, we got a session id - see if we find a user with this session id
	$user_obj = Yggdrasil::User->get_with_session( yggdrasil => $self, session => $session );
    } elsif (-t && ! defined $user && ! defined $pass) {
	# First, let see if we're connected to a tty without getting a
	# username / password, at which point we're already authenticated
	# and we don't want to touch the session.  $> is effective UID.
	my $uname = (getpwuid($>))[0];
	$user_obj = Yggdrasil::User->get( yggdrasil => $self, user => $uname );
	$session = "invalid";
    }

    if( $user_obj ) {
	$self->{yggdrasil}->{storage}->{user} = $user_obj;
	unless( $session ) {
	    $session = md5_hex(time() * $$ * rand(time() + $$));
	    $user_obj->session( $session );
	}
	$self->{session} = $session;
	$status->set( 200 );
    } else {
	$status->set( 403 );
    }

    return $user_obj;
}

# TODO: Sanitycheck $operator, make property-compatible.
sub can {
    my $self = shift;
    my %params = @_;
    
    my $ygg       = $self->{yggdrasil};
    my $target    = $params{targets};
    my $operation = $params{operation};
    my $storage   = $ygg->{storage};
    my $user      = $ygg->user() || '';

    my $dataref   = $params{data};
    my $targets_to_check;
    
    return 1 if grep { /[^:]:[^:]/ } @$target;  # FIX: properties not implemented.
    return 1 if $target eq "Relations"; # FIX: auth for Relation
    return 1 unless $user && $operation eq 'readable'; # Pre-login.
    
    # FIX: This uses get_cached_roles() instead of member_of(), since
    # using the latter causes recursion (since fetching something
    # calles this can() method to check if it can fetch stuff
    my @roles = $user->get_cached_member_of();
    debug_if( 4, "Roleids are " . join(",", map{ $_->id() } @roles) );

    ($targets_to_check, $operation) =
      $self->_get_targets_and_operation( $target, $operation, $dataref );

    #	debug_if( 4, "Requested check of $operation on $target for $user..." );
    for my $entity (@$targets_to_check) {
	return 1 if $operation eq 'readable' && $self->_global_read_access( $entity );
       
	debug_if( 4, "Checking $operation on $entity for $user..." );
	my $permission = $self->_can( $entity, $operation, @roles );
	return unless $permission;
    }
    return 1;
}

sub _get_targets_and_operation {
    my ($self, $targets, $operation, $dataref) = @_;
    my $storage = $self->storage();
    my @targets_to_check;    

    for my $target (@$targets) {
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
	} elsif ($target eq 'Instances' && $operation eq 'store') {
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
	    return [];
	} elsif ($operation eq 'readable') {
	    if (ref $target eq 'ARRAY') {
		for my $t (@$target) {
		    push @targets_to_check, $t;
		}		
	    } else {
		push @targets_to_check, $target;
	    }
	} elsif ($target eq 'MetaAuthEntity') { # FIXME, check parents.
	    return [];
	} elsif ($target eq 'MetaAuthRolemembership') {
	    @targets_to_check = qw|MetaAuthRole|;
	    $operation = 'writeable';
	} else {
	    print "Whopsie, $target\n";
	    if ( $operation =~ /^c/ ) {
		$operation = 'createable';
	    } elsif ($operation =~ /^d/) {
		$operation = 'deleteable';
	    } elsif ($operation =~ /^w/) {
		$operation = 'writeable';
	    } elsif ($operation =~ /^r/) {
		$operation = 'readable';
	    } else {
		print "Whopsie, $operation\n";
		return [];
	    }
	}
    }
    return (\@targets_to_check, $operation);
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
	my $user = Yggdrasil::User->define( yggdrasil => $self, user => $u, password => $requested_users{$u} );

	push( @users, $user );
    }

    return @users;
}


# sub _get_user_role {
#     my $self = shift;
#     my $user = shift;

#     # To avoid recursion, call _fetch directly.  :-/
#     my $ref = $self->{yggdrasil}->{storage}->_fetch( 
# 						    MetaAuthRolemembership => { where => [ user => \qq{Instances.id} ],
# 										return => 'role' },
# 						    Instances     => { where => [ visual_id => $user ]}
# 						   );

#     return $ref->[0]->{role};
# }

sub _can {
    my $self      = shift;
    my $entity    = shift;
    my $operation = shift;
    my @roles     = @_;

    my $ref;
    if ($entity =~ /^\d+/) {
	$ref = $self->{yggdrasil}->{storage}->
	  _fetch( 
		 MetaAuthEntity => { where  => [ role   => \@roles,
						 entity => $entity ],
				     return => $operation },
		);
    } else {
	$ref = $self->{yggdrasil}->{storage}->
	  _fetch( 
		 MetaAuthEntity => { where => [ role => \@roles ],
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

    if ($entity =~ /^Storage/ || $entity =~ /^Meta/ || $entity eq 'Instances') {
	return 1;
    } else {
	return 0;
    }
}

1;
