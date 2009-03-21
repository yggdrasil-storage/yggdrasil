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
    my $uo = $meta_user->create( $params{'user'} );
    $uo->property( password => $params{'password'} );
    
    $self->{_user_obj} = $uo;

    return $self;
}

sub get {
    # gets a user
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
    my $value = shift;

    return $self->_setter_getter( username => $value );
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

    return Yggdrasil::Role->get( yggdrasil => $self, id => $roref->[0]->{visual_id} );
}

1;
