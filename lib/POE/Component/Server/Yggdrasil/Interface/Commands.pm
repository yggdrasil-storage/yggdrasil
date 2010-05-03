package POE::Component::Server::Yggdrasil::Interface::Commands;

use warnings;
use strict;


sub new {
    my $class = shift;
    my %params = @_;
    my $y = $params{yggdrasil};

    my $self = {	
		define_entity    => sub { _define_entity( $y, @_ ) },
		define_property  => sub { _define_property( $y, @_ ) },

		create_instance  => sub { _create_instance( $y, @_ ) },
	       
		get_entity       => sub { _get_entity( $y, @_ ) },
		get_relation     => sub { _get_relation( $y, @_ ) },
		get_property     => sub { _get_property( $y, @_ ) },
		get_instance     => sub { _get_instance( $y, @_ ) },
		get_user         => sub { _get_user( $y, @_ ) },
		get_role         => sub { _get_role( $y, @_ ) },

		get_all_users    => sub { _get_all_users( $y, @_ ) },
		get_all_entities => sub { _get_all_entities( $y, @_ ) },
		
		get_value        => sub { _get_set_value( $y, @_ ) },
		set_value        => sub { _get_set_value( $y, @_ ) },
		
		get_role_value   => sub { _get_set_rolevalue( $y, @_ ) },
		set_role_value   => sub { _get_set_rolevalue( $y, @_ ) },

		get_user_value   => sub { _get_set_uservalue( $y, @_ ) },
		set_user_value   => sub { _get_set_uservalue( $y, @_ ) },
		
		info             => sub { $y->get_status()->set( 200 ); _info( $y, @_ ) },
		yggdrasil        => sub { $y->get_status()->set( 200 ); _info( $y, @_ ) },
		whoami           => sub { $y->get_status()->set( 200 ); return $_[1] },
		uptime           => sub { $y->get_status()->set( 200 ); return $_[1] },
		# ...
	       };  
  

    return bless $self, $class;
}

sub _info {
    my $ygg = shift;
    return $ygg->info();
}
  
sub _define_entity {
    my $ygg = shift;
    my %params = @_;
    
    return $ygg->define_entity( $params{entityid} );    
}

sub _define_property {
    my $ygg = shift;
    my %params = @_;
    
    my $entity = $ygg->get_entity( $params{entityid} );
    return unless $entity;

    my $defined = $entity->define_property( $params{propertyid}, type => $params{type}, null => $params{null} );
    return unless defined $defined;

    # There is some weird things happening when creating properties,
    # not everything is properly objectified, so we have an extra call
    # here to solve that.  The FIXME should go into Property->define().    
    return $entity->get_property( $params{propertyid} );
}

sub _create_instance {
    my $ygg = shift;
    my %params = @_;
    
    my $entity = $ygg->get_entity( $params{entityid} );

    return undef unless $entity;
    return $entity->create( $params{instanceid} );
}

sub _get_entity {
    my $ygg = shift;
    my %params = @_;
    
    return $ygg->get_entity( $params{entityid} );
}

sub _get_property {
    my $ygg = shift;
    my %params = @_;

    my $entity = $ygg->get_entity( $params{entityid} );
    return unless defined $entity;
    return $entity->get_property( $params{propertyid} );
}

# Get all objects of a given type.
sub _get_all_users {
    my $ygg = shift;    
    my @data = $ygg->users();
    return \@data;
}

sub _get_all_entities {
    my $ygg = shift;    
    my @data = $ygg->entities();
    return \@data;
}

# Please note that the label is still assumed to be globally unique,
# so 'relationid' is indeed its label.
sub _get_relation {
    my $ygg = shift;
    my %params = @_;
    
    return $ygg->get_relation( $params{relationid} );
}

sub _get_user {
    my $ygg = shift;
    my %params = @_;
    
    return $ygg->get_user( $params{userid} );
}

sub _get_role {
    my $ygg = shift;
    my %params = @_;
    
    return $ygg->get_role( $params{roleid} );
}

sub _get_instance {
    my $ygg = shift;
    my %params = @_;
    
    my $entity = $ygg->get_entity( $params{entityid} );

    return undef unless $entity;
    return $entity->fetch( $params{instanceid} );
}

sub _get_set_value {
    my $ygg = shift;
    my %params = @_;
    
    my $entity = $ygg->get_entity( $params{entityid} );

    return undef unless $entity;
    my $instance = $entity->fetch( $params{instanceid} );
    
    return undef unless $instance;
    if (exists $params{value}) {
	return ($instance->property( $params{propertyid}, $params{value} ), $instance);
    } else {
	return ($instance->property( $params{propertyid} ), $instance);
    }
    
}

sub _get_set_uservalue {
    my $ygg = shift;
    my %params = @_;

    my $user = $ygg->get_user( $params{userid} );
    return undef unless $user;

    if (exists $params{value}) {
	return ($user->property( $params{propertyid}, $params{value} ), $user);
    } else {
	return ($user->property( $params{propertyid} ), $user);
    }
}

sub _get_set_rolevalue {
    my $ygg = shift;
    my %params = @_;

    my $role = $ygg->get_role( $params{roleid} );
    return undef unless $role;

    if (exists $params{value}) {
	return ($role->property( $params{propertyid}, $params{value} ), $role);
    } else {
	return ($role->property( $params{propertyid} ), $role);
    }
}


1;
