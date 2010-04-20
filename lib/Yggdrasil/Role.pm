package Yggdrasil::Role;

# This class acts as a wrapper class for the entity MetaAuthRole.
# It provides a handy interface to defining, getting, undefining roles,
# as well as getters and setters for some predefined properties.

use strict;
use warnings;

use base qw(Yggdrasil::Object);

use Yggdrasil::Storage::Auth::Role;

sub define {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    my %params = @_;

    my $ro = Yggdrasil::Storage::Auth::Role->define( $self->{yggdrasil}->{storage},
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
	$ro = Yggdrasil::Storage::Auth::Role->get( $self->{yggdrasil}->{storage}, $params{role} );	
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
    for my $role_obj ( Yggdrasil::Storage::Auth::Role->get_all( $self->{yggdrasil}->{storage}) ) {
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

    return map { Yggdrasil::User->get(yggdrasil => $self, user => $_ ) }
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
    my $self   = shift;
    my $schema = shift;

    # Take either the name, or an object as a parameter.
    $schema = $schema->name() if ref $schema;
    $self->{_role_obj}->grant( $schema, @_ )
}

sub revoke {
    my $self   = shift;
    my $schema = shift;

    # Take either the name, or an object as a parameter.
    $schema = $schema->name() if ref $schema;
    $self->{_role_obj}->revoke( $schema, @_ )
}

sub add {
    my $self = shift;
    my $user = shift;

    if (ref $user && ref $user ne 'Yggdrasil::User') {
	$self->get_status()->set( 406, "Unexpected user type (" . ref $user .
				  ") given to role->add(), expected Yggdrasil::User" );
	return;
    }
    
    $self->get_status()->set( 406, "Unable to resolve the user passed to role->add()" )
      unless $user;

    # Encapsulation...
    $self->{_role_obj}->add( $user->{_user_obj} );
	
    return 1 if $self->get_status()->OK();
    return;
}

sub remove {
    my $self = shift;
    my $user = shift;

    if (ref $user && ref $user ne 'Yggdrasil::User') {
	$self->get_status()->set( 406, "Unexpected user type (" . ref $user .
				  ") given to role->remove(), expected Yggdrasil::User" );
	return;
    }
    
    $self->get_status()->set( 406, "Unable to resolve the user passed to role->remove()" )
      unless $user;

    # Encapsulation...
    $self->{_role_obj}->remove( $user->{_user_obj} );
	
    return 1 if $self->get_status()->OK();
    return;
}

1;
