package Yggdrasil::Storage::Auth::Role;

use strict;
use warnings;

sub _new {
    my $class   = shift;
    my $storage = shift;
    my $id      = shift;
    my $role    = shift;

    my $self = bless {}, $class;

    $self->{_name}    = $role;
    $self->{_id}      = $id;
    $self->{_storage} = $storage;

    return $self;
}

sub define {
    my $class   = shift;
    my $storage = shift;
    my $role    = shift;

    my $roleschema = $storage->{structure}->get( 'authrole' );
    my $rid = $storage->store( $roleschema, key => qw/id/, 
			       fields => { name => $role } );

    return unless $rid;
    my $r = $class->_new( $storage, $rid, $role );

    if( $storage->user() ) {
	my @roles = $storage->user()->member_of();
	foreach my $memberrole ( @roles ) {
	    $memberrole->grant( $roleschema => 'm', id => $r->id() );
	}
    }

    $r->grant( $roleschema => 'm', id => $r->id() );

    return $r;
}

sub get {
    my $class   = shift;
    my $storage = shift;
    my $role    = shift;

    my $roleschema = $storage->{structure}->get( 'authrole' );
    my $rid = $storage->fetch(
	$roleschema => {
	    return => 'id',
	    where  => [ name => $role ]
	} );

    return unless $rid;
    my $id = $rid->[0]->{id};
    return unless $id;

    return $class->_new( $storage, $id, $role )
}

sub get_all {
    my $class = shift;
    my $storage = shift;
    
    my $roleschema = $storage->{structure}->get( 'authrole' );
    my $roles = $storage->_fetch(
	$roleschema => {
	    return => [ qw/id name/ ]
	} );

    return unless $roles;

    return map { $class->_new( $storage, $_->{id}, $_->{name} ) } @$roles;
}

sub members :method {
    my $self = shift;

    my $userschema   = $self->{_storage}->{structure}->get( 'authuser' );
    my $memberschema = $self->{_storage}->{structure}->get( 'authmember' );

    my $ret = $self->{_storage}->fetch( 
	$memberschema => {
	    where => [ roleid => $self->id() ],
	},
	
	$userschema => {
	    where  => [ id => \qq<$memberschema.userid> ],
	    return => [ qw/id name/ ],
	} );
	
    return unless $ret;
    
    my @users;
    foreach my $e ( @$ret ) {
	my $user = Yggdrasil::Storage::Auth::User->_new( 
	    $self->{_storage}, $e->{id}, $e->{name} );

	push( @users, $user );
    }

    return @users;
}

sub name :method {
    my $self = shift;

    return $self->{_name};
}

sub id :method {
    my $self = shift;

    return $self->{_id};
}

sub _access :method {
    my $self   = shift;
    my $schema = shift;
    my $mode   = shift;
    my %params = @_;

    return unless ref $mode;

    my $storage = $self->{_storage};

    my $storageauthschema = $self->{_storage}->{structure}->get( 'authschema' );

    # 1. find authschema for schema
    my $authschema = $storage->fetch( $storageauthschema =>
				      {
				       where  => [ usertable => $schema ],
				       return => 'authtable'
				      } );
				     
    return unless $authschema && $authschema->[0]->{authtable};;
    $authschema = $authschema->[0]->{authtable};
 
    # 2. set mode bit in authtable
    $storage->store( $authschema, key => [ qw/id roleid/ ],
		     fields => { id     => $params{id},
				 roleid => $self->id(),
				 @$mode } );
}

sub grant :method {
    my $self   = shift;
    my $schema = shift;
    my $mode   = shift;
  
    my @modes;
    if ($mode eq 'r' ) {
	@modes = qw/r 1/;
    } elsif ($mode eq 'w') {
	@modes = qw/r 1 w 1/;
    } elsif ($mode eq 'm' ) {
	@modes = qw/r 1 w 1 m 1/;
    } 
	 
    $self->_access( $schema, \@modes, @_ );
}

sub revoke :method {
    my $self   = shift;
    my $schema = shift;
    my $mode   = shift;

    my @modes;
    if ($mode eq 'r' ) {
	@modes = qw/r 0 w 0 m 0/;
    } elsif ($mode eq 'w') {
	@modes = qw/w 0 m 0/;
    } elsif ($mode eq 'm' ) {
	@modes = qw/m 0/;
    } 
   
    $self->_access( $schema, \@modes, @_ );
}

sub add :method {
    my $self = shift;
    my $user = shift;

    my $memberschema = $self->{_storage}->{structure}->get( 'authmember' );
    
    $self->{_storage}->store( $memberschema, key => [ qw/userid roleid/ ],
			      fields => { userid => $user->id(),
					  roleid => $self->id() } );

    # FIX STATUS
}

sub remove :method {
    my $self = shift,
    my $user = shift;

    my $memberschema = $self->{_storage}->{structure}->get( 'authmember' );
    $self->{_storage}->expire( $memberschema =>
			       userid => $user->id(),
			       roleid => $self->id() );

    # FIX STATUS
}

1;
