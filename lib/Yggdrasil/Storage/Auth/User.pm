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

    my $uid = $storage->store( $Yggdrasil::Storage::STORAGEAUTHUSER, key => qw/id/,
			       fields => { name => $user, password => $pwd } );

    return unless $uid;
    return $class->_new( $storage, $uid, $user );
}

sub get {
    my $class   = shift;
    my $storage = shift;
    my $user    = shift;

    my $uid = $storage->fetch(
	$Yggdrasil::Storage::STORAGEAUTHUSER => {
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
	$Yggdrasil::Storage::STORAGEAUTHUSER => {
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
	$Yggdrasil::Storage::STORAGEAUTHUSER => {
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
	$Yggdrasil::Storage::STORAGEAUTHUSER => {
	    return => qw/password/,
	    where  => [ id => $self->id() ]
	} );

    return unless $r;
    return $r->[0]->{password};
}

sub member_of :method {
    my $self = shift;

    my $ret = $self->{_storage}->fetch(
       $Yggdrasil::Storage::STORAGEAUTHMEMBER => {
	  where => [ userid => $self->id() ],
       },

       $Yggdrasil::Storage::STORAGEAUTHROLE => {
	  where =>  [ id => \qq<$Yggdrasil::Storage::STORAGEAUTHMEMBER.roleid> ],
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
