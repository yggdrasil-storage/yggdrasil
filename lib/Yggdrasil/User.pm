package Yggdrasil::User;

# This class acts as a wrapper class for the entity MetaAuthUser.
# It provides a handy interface to defining, getting, undefining users,
# as well as getters and setters for some predefined properties.

use strict;
use warnings;

use base qw(Yggdrasil::Object);

use Yggdrasil::Entity;
use Yggdrasil::Role;

sub define {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    my $meta_user = Yggdrasil::Entity->get( yggdrasil => $self, entity => 'MetaAuthUser' );
    my $uo = $meta_user->create( $params{user} );

    # --- Generate a password if one was not passed in
    my $pass = defined $params{password} ? $params{password} : $self->_generate_password();

    $uo->property( password => $pass );
    
    $self->{_user_obj} = $uo;

    return $self;
}

sub get {
    my $class = shift;
    my $self = $class->SUPER::new( @_ );
    my %params = @_;
    
    my $meta_user = Yggdrasil::Entity->get( yggdrasil => $self, entity => 'MetaAuthUser' );
    $self->{_user_obj} = $meta_user->fetch( $params{'user'} );

    return unless $self->{_user_obj};

    $self->_load_memberships();

    return $self;
}

sub start {
    my $self = shift;
    return $self->{_user_obj}->{_start};
}

sub stop {
    my $self = shift;
    return $self->{_user_obj}->{_stop};
}

sub get_with_session {
    my $class = shift;
    my $self = $class->SUPER::new( @_ );
    my %params = @_;

    my $meta_user = Yggdrasil::Entity->get( yggdrasil => $self, entity => 'MetaAuthUser' );
    my @hits = $meta_user->search( session => $params{session} );
    
    return unless @hits == 1;

    $self->{_user_obj} = $hits[0];
    $self->_load_memberships();

    return $self;
}

sub undefine {
    # undefs a user
}

sub _setter_getter {
    my $self = shift;
    my $key  = shift;
    my $val  = shift;

    my $uo = $self->{_user_obj};
    if( defined $val ) {
	 $uo->set( $key => $val );

	# FIX: if setting the password failed, undef should be returned -- check status
	return $val;
    }

    return $uo->get( $key );
}

sub password {
    my $self = shift;
    my $value = shift;

    return $self->_setter_getter( password => $value );
}

sub session {
    my $self = shift;
    my $value = shift;

    return $self->_setter_getter( session => $value );
}

sub username {
    my $self = shift;

    return $self->id();
}

sub fullname {
    my $self = shift;
    my $value = shift;

    return $self->_setter_getter( fullname => $value );
}

sub id {
    my $self = shift;

    return $self->{_user_obj}->{visual_id};
}

# FIX: since Auth->can() asks for User->member_of, which calles
# Storage->fetch which calls Auth->can() which calles User->member_of
# .... etc. we need to cache role membership
sub _load_memberships {
    my $self = shift;

    my @roles = $self->member_of();
    $self->{_roles} = \@roles;
}

sub get_cached_member_of {
    my $self = shift;

    return @{ $self->{_roles} };
}

# FIX1: couldn't we just fetch id and visual_id and make user objects
#       without having to fetch the visual_id's? What about the
#       instance's entity method, how does it get an entity object?
# FIX2: this is ugly
# FIX3: get_roles does mostly the same stuff, but as a class method
#       and it calls _fetch (why?) - possible to consolidate the two?
sub member_of {
    my $self = shift;

    my $uobj = $self->{_user_obj};

    my $roles = $self->storage()->fetch(
	Entities =>
	{ return => [ qw/visual_id/ ], where => [ id => \qq<MetaAuthRolemembership.role> ] },
	MetaAuthRolemembership =>
	{ where => [ user => $uobj->{_id} ] } );
    # FIX fetch does *not* return status code in a sane way.  This
    # needs to be solved at the SQL layer upon completing a
    # transaction.
    # return unless $self->get_status()->OK();
    return map { Yggdrasil::Role->get(yggdrasil => $self, role => $_->{visual_id}) } @$roles;
}

# This is awefully ugly.  FIXME.
sub get_roles {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    my $user = $params{user};
#    my $self = shift;
    
    #my $u = $self->{_user_obj};
    my $idref = $self->storage()->_fetch(MetaAuthRolemembership => { where => [ user => \qq{Entities.id} ],
								     return => 'role' },
					 Entities => { where => [ visual_id => $user ]});

    my $roref = $self->storage()->_fetch(Entities => { where => [ id => $idref->[0]->{role} ],
						       return => 'visual_id' });

    print "$_\n" for caller();

    return Yggdrasil::Role->get( yggdrasil => $self, role => $roref->[0]->{visual_id} );
}

sub _generate_password {
    my $self = shift;
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
