package Storage::Auth::Role;

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

    $self->{_start}   = shift;
    $self->{_stop}    = shift;

    return $self;
}

sub define {
    my $class   = shift;
    my $storage = shift;
    my $role    = shift;

    my $roleschema = $storage->get_structure( 'authrole' );
    my $rid = $storage->store( $roleschema, key => qw/name/, 
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

    my $roleschema = $storage->get_structure( 'authrole' );
    my $rid = $storage->fetch(
	$roleschema => {
	    return => [ 'id', 'start', 'stop' ],
	    where  => [ name => $role ]
	} );

    return unless $rid;
    my $id    = $rid->[0]->{id};
    my $start = $rid->[0]->{start};
    my $stop  = $rid->[0]->{stop};
    return unless $id;

    return $class->_new( $storage, $id, $role, $start, $stop )
}

sub get_nobody {
    my $class   = shift;
    my $storage = shift;

    # FIX: 3? 
    return $class->_new( $storage, 3, "nobody" );
}

sub get_all {
    my $class = shift;
    my $storage = shift;
    
    my $roleschema = $storage->get_structure( 'authrole' );
    my $roles = $storage->_fetch(
	$roleschema => {
	    return => [ qw/id name/ ]
	} );

    return unless $roles;

    return map { $class->_new( $storage, $_->{id}, $_->{name} ) } @$roles;
}

sub start {
    my $self = shift;
    return $self->{_start};
}

sub stop {
    my $self = shift;
    return $self->{_stop};
}

sub description :method {
    my $self = shift;
    return $self->_getter_setter( 'description', @_ );
}

sub get_field {
    my $self = shift;
    return $self->_getter_setter( @_ );
}

sub set_field {
    my $self = shift;
    return $self->_getter_setter( @_ );
}

sub _getter_setter {
    my $self = shift;
    my ($field, $value) = @_;

    my $structure = $self->{_storage}->get_structure( "authrole:$field" );
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

sub members :method {
    my $self = shift;

    my $userschema   = $self->{_storage}->get_structure( 'authuser' );
    my $memberschema = $self->{_storage}->get_structure( 'authmember' );

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
	my $user = Storage::Auth::User->_new( 
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

    my $storageauthschema = $storage->get_structure( 'authschema' );

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

    my $memberschema = $self->{_storage}->get_structure( 'authmember' );
    
    $self->{_storage}->store( $memberschema, key => [ qw/userid roleid/ ],
			      fields => { userid => $user->id(),
					  roleid => $self->id() } );

    # FIX STATUS
}

sub remove :method {
    my $self = shift,
    my $user = shift;

    my $memberschema = $self->{_storage}->get_structure( 'authmember' );
    $self->{_storage}->expire( $memberschema =>
			       userid => $user->id(),
			       roleid => $self->id() );

    # FIX STATUS
}

1;
