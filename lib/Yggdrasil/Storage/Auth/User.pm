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

    return $self;
}

sub define {
    my $class   = shift;
    my $storage = shift;
    my $user    = shift;
    my $pwd     = shift;

    my $uid = $storage->store( $storage->get_structure( 'authuser' ), key => qw/id/,
			       fields => { name => $user, password => $pwd } );

    return unless $uid;
    return $class->_new( $storage, $uid, $user );
}

sub get {
    my $class   = shift;
    my $storage = shift;
    my $user    = shift;

    my $uid = $storage->fetch(
	$storage->get_structure( 'authuser' ) => {
	    return => 'id',
	    where  => [ name => $user ]
	} );

    return unless $uid;
    my $id = $uid->[0]->{id};
    return unless $id;

    return $class->_new( $storage, $id, $user );
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


sub name :method {
    my $self = shift;

    return $self->{_name};
}

sub id :method {
    my $self = shift;

    return $self->{_id};
}

sub password :method {
    my $self = shift;

    my $r = $self->{_storage}->fetch( 
	$self->{_storage}->get_structure( 'authuser' ) => {
	    return => qw/password/,
	    where  => [ id => $self->id() ]
	} );

    return unless $r;
    return $r->[0]->{password};
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
