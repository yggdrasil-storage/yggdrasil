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
		define_relation  => sub { _define_relation( $y, @_ ) },
		define_role      => sub { _define_role( $y, @_ ) },

		define_relation_bind  => sub { _define_relation_bind( $y, @_ ) },

		create_instance  => sub { _create_instance( $y, @_ ) },
	       
		get_entity       => sub { _get_entity( $y, @_ ) },
		get_relation     => sub { _get_relation( $y, @_ ) },
		get_property     => sub { _get_property( $y, @_ ) },
		get_instance     => sub { _get_instance( $y, @_ ) },
		get_user         => sub { _get_user( $y, @_ ) },
		get_role         => sub { _get_role( $y, @_ ) },

		expire_user      => sub { _expire_user( $y, @_ ) },
		expire_instance  => sub { _expire_instance( $y, @_ ) },
		expire_property  => sub { _expire_property( $y, @_ ) },
		expire_entity    => sub { _expire_entity( $y, @_ ) },

		get_all_users      => sub { _get_all_users( $y, @_ ) },
		get_all_roles      => sub { _get_all_roles( $y, @_ ) },
		get_all_entities   => sub { _get_all_entities( $y, @_ ) },

		get_entity_children      => sub { _get_entity_children( $y, @_ ) },
		get_entity_ancestors     => sub { _get_entity_ancestors( $y, @_ ) },
		get_entity_descendants   => sub { _get_entity_decendants( $y, @_ ) },
		get_all_entity_relations => sub { _get_all_entity_relations( $y, @_ ) },
		get_all_instances        => sub { _get_all_instances( $y, @_ ) },
		get_all_properties       => sub { _get_all_properties( $y, @_ ) },

		get_all_relations  => sub { _get_all_relations( $y, @_ ) },

		get_property_meta  => sub { _get_property_meta( $y, @_ ) },
		get_property_types => sub { _get_property_types( $y, @_ ) },
		
		get_value         => sub { _get_set_value( $y, @_ ) },
		set_value         => sub { _get_set_value( $y, @_ ) },

		get_ticks         => sub { _get_ticks( $y, @_ ) },
		get_ticks_by_time => sub { _get_ticks_by_time( $y, @_ ) },
		get_current_tick  => sub { _get_current_tick( $y ) },
		
		get_search        => sub { _get_search( $y, @_ ) },

		get_can           => sub { _get_can( $y, @_ ) },
		get_size          => sub { _get_size( $y, @_ ) },
		
		get_role_value   => sub { _get_set_rolevalue( $y, @_ ) },
		set_role_value   => sub { _get_set_rolevalue( $y, @_ ) },

		get_user_value   => sub { _get_set_uservalue( $y, @_ ) },
		set_user_value   => sub { _get_set_uservalue( $y, @_ ) },

		get_roles_of     => sub { _get_roles_of( $y, @_ ) },
		get_members      => sub { _get_members( $y, @_ ) },

		get_relation_participants => sub { _get_relation_participants( $y, @_ ) },
		
		role_add_user    => sub { _role_addremove_user( $y, 'add', @_ ) },
		role_remove_user => sub { _role_addremove_user( $y, 'remove', @_ ) },
		role_grant       => sub { _role_grant( $y, @_ ) },
		role_revoke      => sub { _role_revoke( $y, @_ ) },

		info             => sub { $y->get_status()->set( 200 ); _info( $y, @_ ) },
		yggdrasil        => sub { $y->get_status()->set( 200 ); _info( $y, @_ ) },
		whoami           => sub { $y->get_status()->set( 200 ); return $_[1] },
		uptime           => sub { $y->get_status()->set( 200 ); return $_[1] },
		# ...
	       };  
  

    return bless $self, $class;
}

# Handle temporality in the proper fashion.
sub _populate_time {
    my %params = @_;
    if (exists $params{start} || exists $params{stop}) {
	return ( time => {
			  start  => $params{start},
			  stop   => $params{stop},
			  format => $params{format},
			 });
    } else {
	return ();
    }
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

sub _define_relation {
    my $ygg = shift;
    my %params = @_;

    my $lval = $ygg->get_entity( $params{lval} );
    return unless $lval;

    my $rval = $ygg->get_entity( $params{rval} );
    return unless $rval;

    return $ygg->define_relation( $lval, $rval, @_ );
}

sub _define_relation_bind {
    my $ygg = shift;
    my %params = @_;
    
    my $relation = $ygg->get_relation( $params{relationid} );
    return unless $relation;

    my $le = $relation->{lval};
    my $re = $relation->{rval};

    my $lval = $ygg->get_instance( $le, $params{lval} );
    return unless $lval;

    my $rval = $ygg->get_instance( $re, $params{rval} );
    return unless $rval;
   
    return $relation->link( $lval, $rval, @_ );
}

sub _define_property {
    my $ygg = shift;
    my %params = @_;
    
    my $entity = $ygg->get_entity( $params{entityid} );
    return unless $entity;

    my $defined = $entity->define_property( $params{propertyid}, type => $params{type}, nullp => $params{nullp} );
    return unless defined $defined;

    # There is some weird things happening when creating properties,
    # not everything is properly objectified, so we have an extra call
    # here to solve that.  The FIXME should go into Property->define().    
    return $entity->get_property( $params{propertyid} );
}

sub _define_role {
    my $ygg = shift;
    my %params = @_;
    
    return $ygg->define_role( $params{roleid} );    
}

sub _expire_user {
    my $ygg = shift;
    my %params = @_;

    return $ygg->expire_user( $params{userid} );    
}

sub _expire_instance {
    my $ygg = shift;
    my %params = @_;

    $ygg->expire_instance( $params{entityid}, $params{instanceid} );
    if ($ygg->get_status()->OK()) {
	return "OK";
    } 
}

sub _expire_entity {
    my $ygg = shift;
    my %params = @_;

    return $ygg->expire_entity( $params{entityid} );
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
    return $ygg->get_entity( $params{entityid}, _populate_time( @_ ) );
}

sub _get_property {
    my $ygg = shift;
    my %params = @_;

    my $entity = $ygg->get_entity( $params{entityid}, _populate_time( @_ ) );
    return unless defined $entity;
    return $entity->get_property( $params{propertyid} );
}

sub _expire_property {
    my $ygg = shift;
    my %params = @_;

    my $entity = $ygg->get_entity( $params{entityid} );
    return unless $entity;
    my $property = $entity->get_property( $params{propertyid} );
    return unless $property;
    return $property->expire();
}


# Get all objects of a given type.
sub _get_all_users {
    my $ygg = shift;    
    my @data = $ygg->users( _populate_time( @_ ) );
    return \@data;
}

sub _get_all_roles {
    my $ygg = shift;    
    my @data = $ygg->roles( _populate_time( @_ ) );
    return \@data;
}

sub _get_all_entities {
    my $ygg = shift;
    my @data = $ygg->entities( _populate_time( @_ ) );
    return \@data;
}

sub _get_all_instances {
    my $ygg = shift;    
    my %params = @_;

    # Yggdrasil will take care of the entity->get() and perform it
    # temporally if needed.  ygg->instances( e, temporal ) is
    # identical to calling ygg->get_entity( e, temporal )->instances()
    my @data = $ygg->instances( $params{entityid}, _populate_time( @_ ) );
    for my $i (@data) {
	$i->{id} = $i->_userland_id();
    }
    return \@data;
}

sub _get_all_entity_relations {
    my $ygg = shift;    
    my %params = @_;
    my $entity = $ygg->get_entity( $params{entityid}, _populate_time( @_ ) );
    my @data = $entity->relations();
    for my $i (@data) {
	$i->{id} = $i->_userland_id();
    }
    return \@data;
}

sub _get_entity_decendants {
    my $ygg = shift;
    my %params = @_;
    my $entity = $ygg->get_entity( $params{entityid}, _populate_time( @_ ) );
    my @data = $entity->descendants();
    return \@data;
}

sub _get_entity_ancestors {
    my $ygg = shift;
    my %params = @_;
    my $entity = $ygg->get_entity( $params{entityid}, _populate_time( @_ ) );
    my @data = $entity->ancestors();
    return \@data;
}

sub _get_entity_children {
    my $ygg = shift;
    my %params = @_;
    my $entity = $ygg->get_entity( $params{entityid}, _populate_time( @_ ) );
    my @data = $entity->children();
    return \@data;
}

sub _get_all_properties {
    my $ygg = shift;
    my %params = @_;
    my @data = $ygg->properties( $params{entityid}, _populate_time( @_ ) );
    return \@data;
}

sub _get_all_relations {
    my $ygg = shift;
    my %params = @_;
    my @data = $ygg->relations( $params{entityid}, _populate_time( @_ ) );
    return \@data;
}

# Please note that the label is still assumed to be globally unique,
# so 'relationid' is indeed its label.
sub _get_relation {
    my $ygg = shift;
    my %params = @_;
    
    return $ygg->get_relation( $params{relationid}, _populate_time( @_ ) );
}

sub _get_user {
    my $ygg = shift;
    my %params = @_;
    
    return $ygg->get_user( $params{userid}, _populate_time( @_ ) );
}

sub _get_role {
    my $ygg = shift;
    my %params = @_;
    
    return $ygg->get_role( $params{roleid}, _populate_time( @_ ) );
}

sub _get_instance {
    my $ygg = shift;
    my %params = @_;
    
    my $entity = $ygg->get_entity( $params{entityid}, _populate_time( @_ ) );

    return undef unless $entity;
    my @nodes = $entity->fetch( $params{instanceid}, time => $params{time} );
    return \@nodes;
}

sub _get_set_value {
    my $ygg = shift;
    my %params = @_;
    
    my $entity = $ygg->get_entity( $params{entityid}, _populate_time( @_ ) );

    return undef unless $entity;
    my $instance = $entity->fetch( $params{instanceid} );
    
    return undef unless $instance;
    if (exists $params{value}) {
	return [ $instance->property( $params{propertyid}, $params{value} ), $instance ];
    } else {
	return [ $instance->property( $params{propertyid} ), $instance ];
    }
    
}

sub _get_set_uservalue {
    my $ygg = shift;
    my %params = @_;

    my $user = $ygg->get_user( $params{userid}, _populate_time( @_ ) );
    return undef unless $user;

    if (exists $params{value}) {
	return $user->property( $params{propertyid}, $params{value} );
    } else {
	return $user->property( $params{propertyid} );
    }
}

sub _get_set_rolevalue {
    my $ygg = shift;
    my %params = @_;

    my $role = $ygg->get_role( $params{roleid}, _populate_time( @_ ) );
    return undef unless $role;

    if (exists $params{value}) {
	return $role->property( $params{propertyid}, $params{value} );
    } else {
	return $role->property( $params{propertyid} );
    }
}

sub _get_roles_of {
    my $ygg = shift;
    my %params = @_;

    my $user = $ygg->get_user( $params{userid}, _populate_time( @_ ) );
    return unless $user;
    
    my @roles = $user->member_of();
    return \@roles;
}

sub _get_members {
    my $ygg = shift;
    my %params = @_;

    my $role = $ygg->get_role( $params{roleid}, _populate_time( @_ ) );
    return unless $role;

    my @users = $role->members();
    return \@users;
}

sub _get_relation_participants {
    my $ygg = shift;
    my %params = @_;

    my $relation = $ygg->get_relation( $params{relationid}, _populate_time( @_ ) );
    return unless $relation;

    my @instance_sets;
    for my $set ($relation->participants()) {
	my %container;
	$container{lval} = $set->[0]->id();
	$container{rval} = $set->[1]->id();
	push @instance_sets, \%container;
    }
    return \@instance_sets;
}

sub _role_addremove_user {
    my $ygg    = shift;
    my $type   = shift;
    my %params = @_;

    my $role = $ygg->get_role( $params{roleid} );
    return unless $role;

    my $user = $ygg->get_user( $params{userid} );
    return unless $user;

    if( $type eq 'add' ) {
	return $role->add( $user );
    } else {
	return $role->remove( $user );
    }
}

sub _role_grant {
    my $ygg = shift;
    my %params = @_;

    my $role = $ygg->get_role( $params{roleid} );
    return unless $role;

    $role->grant( $params{schema}, $params{mode}, id => $params{id} );
}

sub _role_revoke {
    my $ygg = shift;
    my %params = @_;

    my $role = $ygg->get_role( $params{roleid} );
    return unless $role;

    $role->revoke( $params{schema}, $params{mode}, id => $params{id} );
}

sub _get_ticks {
    my $ygg = shift;
    $ygg->get_status()->set( 200 );
    my @ticks = $ygg->get_ticks( @_ );
    return \@ticks;
}

sub _get_ticks_by_time {
    my $ygg = shift;
    my %params = @_;
    
    $ygg->get_status()->set( 200 );
    my @ticks;

    if (exists $params{stop}) {
	@ticks = $ygg->get_ticks_by_time( $params{start}, $params{stop} );
    } else {
	@ticks = $ygg->get_ticks_by_time( $params{start} );
    }

    return \@ticks;
}

sub _get_current_tick {
    my $ygg = shift;
    $ygg->get_status()->set( 200 );
    return $ygg->current_tick();
}

sub _get_search {
    my $ygg = shift;
    my %params = @_;

    my ($e, $i, $p, $r) = $ygg->search( $params{search}, _populate_time( @_ ) );
    my @all_hits = (@$e, @$i, @$p, @$r);

    return \@all_hits;
}

sub _get_can {
    my $ygg = shift;
    my %params = @_;

    return $ygg->storage()->can( $params{operation} => $params{target}, { $params{key} => $params{value} } ) || 0;
}

sub _get_size {
    my $ygg = shift;
    return $ygg->storage()->size( @_ );
}

sub _get_property_meta {
    my $ygg = shift;
    my %params = @_;

    my $p = $ygg->get_property( $params{entityid}, $params{propertyid}, _populate_time( @_ ) );
    return unless $p;
    
    if ($params{meta} eq 'null') {
	return $p->null();	
    } elsif ($params{meta} eq 'type') {
	return $p->type();
    } else {
	$ygg->get_status()->set( 406, "Unknown meta request ($params{meta})" );
	return undef;
    }
}

sub _get_property_types {
    my $ygg = shift;
    my @types = $ygg->property_types( _populate_time( @_ ) );

    return \@types;
}

1;
