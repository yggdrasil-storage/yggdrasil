package Storage::Auth::User;

use strict;
use warnings;

sub _new {
    my $class   = shift;
    my $storage = shift;
    my $id      = shift;
    my $user    = shift;

    my $self = bless {}, $class;

    $self->{_name}    = $user;
    $self->{_id}      = $id;
    $self->{_storage} = $storage;

    $self->{_start}   = shift;
    $self->{_stop}    = shift;

    return $self;    
}

sub define {
    my $class   = shift;
    my $storage = shift;
    my $user    = shift;
    my $pwd     = shift;
    
    my $uid = $storage->store( $storage->get_structure( 'authuser' ),
			       key => qw/name/,
			       fields => { name => $user } );
    return unless $uid;
    
    $storage->store( $storage->get_structure( 'authuser:password' ),
		     key => qw/id/,
		     fields => {
				id    => $uid,
				value => $pwd, 
			       });
    
    # specifically grant rights to nobody role
    my $nobody_role = Storage::Auth::Role->get_nobody( $storage );
    $nobody_role->grant( $storage->get_structure( 'authuser' ), 
			 'r', id => $uid );
    $nobody_role->grant( $storage->get_structure( 'authuser:password' ),
			 'r', id => $uid );

    return $class->_new( $storage, $uid, $user );
}

sub get {
    my $class   = shift;
    my $storage = shift;
    my $user    = shift;
    my $idfield = shift || 'name';

    # warn if idfield anything but id or name.
    my $uid = $storage->fetch(
	$storage->get_structure( 'authuser' ) => {
	    return => [ qw<id name start stop> ],
	    where  => [ $idfield => $user ]
	} );

    return unless $uid;
    my $id    = $uid->[0]->{id};
    my $start = $uid->[0]->{start};
    my $stop  = $uid->[0]->{stop};
    my $name  = $uid->[0]->{name};
    return unless $id;

    return $class->_new( $storage, $id, $name, $start, $stop );
}

sub get_bootstrap {
    my $class   = shift;
    my $storage = shift;
    
    return $class->_new( $storage, 1, 'bootstrap', 1 );
}

sub get_nobody {
    my $class = shift;
    my $storage = shift;
    
    return $class->_new( $storage, 2, "nobody" );
}

sub get_all {
    my $class = shift;
    my $storage = shift;
    
    my $users = $storage->fetch(
	$storage->get_structure( 'authuser' ) => {
	    return => [ qw/id name/ ]
	} );
    
    return unless $users;
    
    return map { $class->_new( $storage, $_->{id}, $_->{name} ) } @$users;
}

sub get_by_session {
    my $class = shift;
    my $storage = shift;
    my $session = shift;
    
    my $hits = $storage->fetch(
	$storage->get_structure( 'authuser:session' ) => {
	    return => 'id',
	    where  => [ value => $session ]
	} );

    return unless @$hits == 1;
    return $class->get( $storage, $hits->[0]->{id}, 'id' );
}

sub id :method {
    my $self = shift;
    return $self->{_id};
}

sub start {
    my $self = shift;
    return $self->{_start};
}

sub stop {
    my $self = shift;
    return $self->{_stop};
}

sub name :method {
    my $self = shift;
    return $self->{_name};
}

sub username :method {
    my $self = shift;
    return $self->name();
}

sub password :method {
    my $self = shift;
    return $self->_getter_setter( 'password', @_ );
}

sub session :method {
    my $self = shift;
    return $self->_getter_setter( 'session', @_ );
}

sub cert :method {
    my $self = shift;
    return $self->_getter_setter( 'cert', @_ );
}

sub fullname {
    my $self = shift;
    return $self->_getter_setter( 'fullname', @_ );
}

sub expire {
    my $self = shift;
    $self->{_storage}->expire(
			      $self->{_storage}->get_structure( "authuser" ),
			      id => $self->id(),
			     );
}

sub delete :method {
    my $self = shift;
    return $self->expire();
}

sub get_field {
    my $self = shift;
    return $self->_getter_setter( @_ );
}

sub set_field {
    my $self = shift;
    return $self->_getter_setter( @_ );
}

# Worth noting, this doesn't have to deal with times, even if the
# structures are temporal.  That temporality exists only to check what
# has been, not to allow permissions to be used in a temporal fashion.
sub _getter_setter {
    my $self = shift;
    my ($field, $value) = @_;

    my $structure = $self->{_storage}->get_structure( "authuser:$field" );
    my $r;
    
    if (defined $value) {
	$r = $self->{_storage}->store( $structure,
				       key    => 'id',
				       fields => {
						  id    => $self->id(),
						  value => $value,
						 });
    } 

    return unless $self->{_storage}->get_status()->OK();

    $r = $self->{_storage}->fetch( $structure => {
						  return => 'value',
						  where  => [ id => $self->id() ],
						 } );	
    return $r->[0]->{value};
}

sub is_a_member_of {
    my $self = shift;
    my $rolename = shift;

    for my $role ($self->member_of()) {
	return $role if $role->name() eq $rolename;
    }
    return undef;
}

sub member_of :method {
    my $self = shift;

    my $memberschema = $self->{_storage}->get_structure( 'authmember' );
    my $roleschema   = $self->{_storage}->get_structure( 'authrole' );
    my $ret = $self->{_storage}->fetch(
       $memberschema => {
	  where => [ userid => $self->id() ],
       },

       $roleschema => {
	  where =>  [ id => \qq<$memberschema.roleid> ],
  	  return => [ qw/id name/ ],
       }, );
    
    return unless $ret;

    my @roles;
    foreach my $e ( @$ret ) {
	my $role = Storage::Auth::Role->_new(
	    $self->{_storage}, $e->{id}, $e->{name} );

	push( @roles, $role );
    }

    return @roles;
}

1;
