package Yggdrasil::Storage::Auth::User;

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
    
    $pwd = $storage->get_mapper()->map( $pwd ) if $pwd;

    my $uid = $storage->store( $storage->get_structure( 'authuser' ),
			       key => qw/id/,
			       fields => { name => $user } );

    $storage->store( $storage->get_structure( 'authuser:password' ),
		     key => qw/id/,
		     fields => {
				id    => $uid,
				value => $pwd, 
			       });
    
    return unless $uid;
    return $class->_new( $storage, $uid, $user );
}

sub get {
    my $class   = shift;
    my $storage = shift;
    my $user    = shift;

    my $uid = $storage->fetch(
	$storage->get_structure( 'authuser' ) => {
	    return => [ qw<id start stop> ],
	    where  => [ name => $user ]
	} );

    return unless $uid;
    my $id    = $uid->[0]->{id};
    my $start = $uid->[0]->{start};
    my $stop  = $uid->[0]->{stop};
    return unless $id;

    return $class->_new( $storage, $id, $user, $start, $stop );
}

sub get_nobody {
    my $class = shift;
    my $storage = shift;
    
    my $uid = $storage->_fetch(
	$storage->get_structure( 'authuser' ) => {
	    return => 'id',
	    where  => [ name => "nobody" ]
	} );

    return unless $uid;
    my $id = $uid->[0]->{id};
    return unless $id;

    return $class->_new( $storage, $id, "nobody" );
}

sub get_all {
    my $class = shift;
    my $storage = shift;
    
    my $users = $storage->_fetch(
	$storage->get_structure( 'authuser' ) => {
	    return => [ qw/id name/ ]
	} );
    
    return unless $users;
    
    return map { $class->_new( $storage, $_->{id}, $_->{name} ) } @$users;
}


sub id :method {
    my $self = shift;

    return $self->{_id};
}

sub start {
    my $self = shift;
    return $self->{_start};
}

sub name :method {
    my $self = shift;

    return $self->{_name};
}

sub password :method {
    my $self = shift;
    $_[1] = $self->{_storage}->get_mapper()->map( $_[1] ) if @_ == 2 && defined $_[1];
    
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

    $r = $self->{_storage}->fetch( $structure => {
						  return => 'value',
						  where  => [ id => $self->id() ],
						 } );	
    return $r->[0]->{value};
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
	my $role = Yggdrasil::Storage::Auth::Role->_new(
	    $self->{_storage}, $e->{id}, $e->{name} );

	push( @roles, $role );
    }

    return @roles;
}

1;
