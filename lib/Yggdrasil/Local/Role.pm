package Yggdrasil::Local::Role;

# This class acts as a wrapper class for the entity MetaAuthRole.
# It provides a handy interface to defining, getting, undefining roles,
# as well as getters and setters for some predefined properties.

use strict;
use warnings;

use base qw/Yggdrasil::Role/;

use Storage::Auth::Role;

sub define {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    my %params = @_;

    my $ro = Storage::Auth::Role->define( $self->{yggdrasil}->{storage},
						     $params{role},
						   );


    $self->{_role_obj} = $ro;
    return $self;
}

sub get {
    my $class = shift;
    my $self = $class->SUPER::new( @_ );
    my %params = @_;

    my $ro;
    if (ref $params{role}) {
	$ro = $params{role};
    } else {
	$ro = Storage::Auth::Role->get( $self->{yggdrasil}->{storage}, $params{role} );	
    }
    
    $self->{_role_obj} = $ro;

    # Status?
    unless ($self->{_role_obj}) {
	$self->get_status()->set( 404 );
	return;
    }
    return $self;
}

sub get_all {
    my $class = shift;
    my $self  = $class->SUPER::new( @_ );
    my %params = @_;

    my @roles;
    for my $role_obj ( Storage::Auth::Role->get_all( $self->{yggdrasil}->{storage}) ) {
	push( @roles, $class->get( yggdrasil => $self, role => $role_obj ) );
    }
    
    return @roles;
}

sub start {
    my $self = shift;
    return $self->{_role_obj}->start();
}

sub stop {
    my $self = shift;
    return $self->{_role_obj}->stop();
}

sub expire {
    my $self = shift;
    $self->{_role_obj}->expire();
}

sub _setter_getter {
    my $self = shift;
    my $key  = shift;
    my $val  = shift;

    my $ro = $self->{_role_obj};
    if( defined $val ) {
	$ro->set_field( $key => $val );
	return $val;
    }

    return $ro->get_field( $key );
}

# Instance-like interface.
sub property {
    my ($self, $key, $value) = @_;
    
    my $status = $self->get_status();
    my %accepted_properties = (
			       description => 1,
			      );

    unless ($accepted_properties{$key}) {
	$status->set( 404, "Roles have no property '$key'" );
	return;
    }
    
    return $self->_setter_getter( $key, $value );
}

sub members {
    my $self = shift;

    return map { Yggdrasil::Local::User->get(yggdrasil => $self, user => $_ ) }
      $self->{_role_obj}->members();
}

sub description {
    my $self = shift;
    my $value = shift;

    return $self->_setter_getter( description => $value );
}

sub name {
    my $self = shift;
    return $self->id();    
}

sub rolename {
    my $self = shift;
    return $self->id();
}

sub id {
    my $self = shift;
    return $self->{_role_obj}->name();
}

sub grant {
    my $self = shift;

    return $self->_grant_revoke( grant => @_ );
}

sub revoke {
    my $self   = shift;

    return $self->_grant_revoke( revoke => @_ );
}

sub _grant_revoke {
    my $self = shift;
    my $op   = shift;
    my $priv = shift;

    foreach my $o ( @_ ) {
	# FIX: $o is not a ref, should we tell some about that?
	next unless ref $o;

	my( $schema, $id );
	if( $o->isa('Yggdrasil::Entity') ) {
	    $schema = "MetaEntity";
	} elsif( $o->isa('Yggdrasil::Instance') ) {
	    $schema = "Instances";
	} elsif( $o->isa('Yggdrasil::Relation') ) {
	    $schema = "MetaRelation";
	} elsif( $o->isa('Yggdrasil::Property') ) {
	    $schema = "MetaProperty";
	} else {
	    # FIX: Tell someone that we didn't recognize their object?
	    next;
	}

	if( $op eq "grant" ) {
	    $self->{_role_obj}->grant( $schema => $priv, id => $o->_internal_id() );
	} elsif( $op eq "revoke" ) {
	    $self->{_role_obj}->revoke( $schema => $priv, id => $o->_internal_id() );
	}
    }
    
}

sub add {
    my $self = shift;
    my $user = shift;

    $user = $self->_check_user($user);
    return unless $user;

    # Encapsulation...
    $self->{_role_obj}->add( $user->{_user_obj} );
	
    return 1 if $self->get_status()->OK();
    return;
}

sub remove {
    my $self = shift;
    my $user = shift;

    $user = $self->_check_user($user);
    return unless $user;

    # Encapsulation...
    $self->{_role_obj}->remove( $user->{_user_obj} );
	
    return 1 if $self->get_status()->OK();
    return;
}

1;
