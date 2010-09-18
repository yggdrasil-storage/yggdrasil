package Yggdrasil::Test::Common;

use strict;
use warnings;

use Test::More;

use Yggdrasil;
use Yggdrasil::Common::Config;
use Storage::Status;

use Digest::SHA qw|sha256_hex|;

our $Y = 'Yggdrasil';
our $Y_E = 'Yggdrasil::Entity';
our $Y_P = 'Yggdrasil::Property';
our $Y_U = 'Yggdrasil::User';
our $Y_Ro = 'Yggdrasil::Role';
our $Y_Re = 'Yggdrasil::Relation';
our $Y_E_I = 'Yggdrasil::Instance';

our $Y_S = 'Storage::Status';

sub import {
    my $class = shift;
    my $tests = shift;

    unless( defined $ENV{YGG_ENGINE} ) {
	plan skip_all => q<Don't know how to connect to any storage engines>; #'
    }

    plan tests => $tests;
}

sub new {
    my $class = shift;
    my $self  = {};

    $self->{label} = $ENV{YGG_LABEL} || 'default';
    my $c = Yggdrasil::Common::Config->new();
    $self->{config} = $c->get( $self->{label} ) || $c->get('ENV');

    return bless $self, $class;
}

sub new_yggdrasil {
    my $self = shift;

    my $y = Yggdrasil->new();
    $self->{ygg} = $y;

    isa_ok( $y, $Y, "$Y->new(): return value" );
    ok( $self->OK(), "$Y->new(): completed with status ".$self->code() );

    return $y;
}

sub connect {
    my $self = shift;

    my $c = $self->{config};
    my $r = $self->{ygg}->connect( engine    => $c->get('enginetype'),
				   host      => $c->get('enginehost'),
				   port      => $c->get('engineport'),
				   db        => $c->get('enginedb'),
				   user      => $c->get('engineuser'),
				   password  => $c->get('enginepassword'),
				   @_
	);
    is( $r, 1, "$Y->connect(): return value was true" );
    ok( $self->OK(), "$Y->connect(): completed with status ".$self->code() );

}

sub bootstrap {
    my $self = shift;

    my $r = $self->{ygg}->bootstrap( @_ );

    my $prefix = "$Y->bootstrap()";
    if( $self->code() == 406 ) {
	is( $self->code(), 406, "$prefix: Has already been completed" );
	is( $r, undef, "$prefix: Return value ok (undef)" );
	ok( 1, "$prefix: dummy test" );
    } else {
	ok( $self->OK(), "$prefix: Completed with status " . $self->code() );
	isa_ok( $r, 'HASH', "$prefix: Return value isa HASH" );
	ok( exists $r->{root}, "$prefix: Has root user" );

	return $r;
    }
}

sub login {
    my $self = shift;
    
    my $c = $self->{config};
    my $user = $c->get('authuser') || (getpwuid($>))[0];
    my $pass = $c->get('authpass');
    my $r = $self->{ygg}->login( username => $user, password => $pass );
    ok( defined($r), "$Y->login(): Authenticated as $r" );
    ok( $self->OK(), "$Y->login(): Logged in with status ".$self->code() );
}

sub entity_define_property {
    my $self = shift;
    my $entity = shift;
    my $name = shift;

    my $p = $entity->define_property( $name );
    $self->_check_property( $p, name => $name, entity => $entity, pkg => $Y_E, func => 'define_property' );
    return $p;
}

sub yggdrasil_define_entity {
    my $self = shift;
    my $name = shift;
    my %data = @_;

    my $expected_name = join("::", grep { defined() } $data{inherit}, $name );

    my $e = $self->{ygg}->define_entity( $name, @_ );
    $self->_check_entity( $e, name => $expected_name, pkg => $Y, func => 'define_entity' );

    return $e;
}

sub yggdrasil_define_relation {
    my $self = shift;
    my $e1 = shift;
    my $e2 = shift;
    my $label = shift;

    my $r = $self->{ygg}->define_relation( $e1, $e2, label => $label );
    $self->_check_relation( $r, name => $label, pkg => $Y, func => 'define_relation' );

    return $r;
}

sub yggdrasil_define_user {
    my $self = shift;
    my $name = shift;

    my $user = $self->{ygg}->define_user( $name, @_ );
    $self->_check_user( $user, name => $name, pkg => $Y, func => 'define_user', @_ );

    return $user;
}

sub yggdrasil_get_user {
    my $self = shift;
    my $name = shift;

    my $user = $self->{ygg}->get_user( $name );
    $self->_check_user( $user, name => $name, pkg => $Y, func => 'get_user' );

    return $user;
}

sub yggdrasil_define_role {
    my $self = shift;
    my $name = shift;

    my $role = $self->{ygg}->define_role( $name );
    $self->_check_role( $role, name => $name, pkg => $Y, func => 'define_role' );
    
    return $role;
}

sub yggdrasil_get_role {
    my $self = shift;
    my $name = shift;

    my $role = $self->{ygg}->get_role( $name );
    $self->_check_role( $role, name => $name, pkg => $Y, func => 'get_role' );
    
    return $role;
}

sub create_instance {
    my $self = shift;
    my $e = shift;
    my $name = shift;

    my $i = $e->create( $name );
    $self->_check_instance( $i, name => $name, func => 'create' );
    return $i;
}

sub get_instance {
    my $self = shift;
    my $e = shift;
    my $name = shift;
    my $num = shift;

    my @i = $e->fetch( $name, @_ );
    for my $i (@i) {
	$self->_check_instance( $i, name => $name, func => 'get' );
    }

    if( defined $num ) {
	my $n = @i;
	ok( @i == $num, "$Y_E_I->get(): Got $n instances" );
    }

    return @i;
}

sub set_instance_property {
    my $self = shift;
    my $i = shift;
    my $key = shift;
    my $val = shift;

    my $r = $i->set( $key => $val );
    is( $r, $val, "$Y_E_I->set(): Return value was '$r'" );
    ok( $self->OK(), "$Y_E_I->set(): Set property '$key' with status " . $self->code() );

    $r = $i->get( $key );
    is( $r, $val, "$Y_E_I->get(): Return value was '$r'" );
    ok( $self->OK(), "$Y_E_I->get(): Got property '$key' with status " . $self->code() );
}

sub fetch_related {
    my $self = shift;
    my $i = shift;
    my $e = shift;
    my $a = shift;

    my $prefix = "$Y_E_I->fetch_related()";
    my $num = @$a;
    my $ename = $e->id();
    my $iname = $i->id();

    my %einstances;
    @einstances{@$a} = (1) x $num;

    my @r = $i->fetch_related( $e );
    ok( $self->OK(), "$prefix: Returned with status " . $self->code() );
    ok( @r == $num, "$prefix: $num '$ename' related to '$iname'" );
    foreach my $r (@r) {
	isa_ok( $r, $Y_E_I, "$prefix: Returned object" );
	my $id = $r->id();
	ok( delete $einstances{$id}, "$prefix: Was related to '$id'" );
    }

    ok( ! keys %einstances, "$prefix: No unexpected relations" );

    return @r;
}

sub add_user_to_role {
    my $self = shift;
    my $r = shift;
    my $u = shift;

    my $res = $r->add($u);
    ok( $res, "$Y_Ro->add(): Added User to Role" );
    ok( $self->OK(), "$Y_Ro->add(): Added with status " . $self->code() );
}

sub remove_user_from_role {
    my $self = shift;
    my $r = shift;
    my $u = shift;
    
    my $res = $r->remove($u);
    ok( $res, "$Y_Ro->remove(): Removed User from Role" );
    ok( $self->OK(), "$Y_Ro->remove(): Removed with status " . $self->code() );
}

sub check_role_members {
    my $self = shift;
    my $role = shift;
    my $expected_users = shift;

    my $n = @$expected_users;
    my $id = $role->id();

    my %eusers;
    @eusers{@$expected_users} = (1) x $n;

    my $prefix = "$Y_Ro->members()";

    my @u = $role->members();
    ok( @u == $n, "$prefix: $id has $n member" );

    foreach my $u (@u) {
	isa_ok( $u, $Y_U, "$prefix: Return value" );
	my $uid = $u->id();
	ok( delete $eusers{$uid}, "$prefix: Has member $uid" );
    }

    ok( ! keys %eusers, "$prefix: No unexpected members" );
}


sub check_user_membership {
    my $self = shift;
    my $user = shift;
    my $expected_roles = shift;

    my $n  = @$expected_roles;
    my $id = $user->id();

    my %eroles;
    @eroles{@$expected_roles} = (1) x $n;

    my $prefix = "$Y_U->member_of()";

    my @r = $user->member_of();
    ok( @r == $n, "$prefix: $id is member of $n roles" );

    foreach my $r (@r) {
	isa_ok( $r, $Y_Ro, "$prefix: Return value" );

	my $rid = $r->id();
	ok( delete $eroles{$rid}, "$prefix: Member of $rid" );
    }

    ok( ! keys %eroles, "$prefix: Not member of any unexpected roles" );
}


sub _check_role {
    my $self = shift;
    my $r    = shift;
    my %data = @_;

    my $name = $data{name};
    my $pkg  = $data{pkg};
    my $func = $data{func};

    my $prefix = "$pkg->$func()";

    isa_ok( $r, $Y_Ro, "$prefix: Return value" );
    is( $r->id(), $name, "$prefix: Role name was $name" );
}

sub _check_user {
    my $self = shift;
    my $u    = shift;
    my %data = @_;

    my $name = $data{name};
    my $pkg  = $data{pkg};
    my $func = $data{func};

    my $prefix = "$pkg->$func()";

    isa_ok( $u, $Y_U, "$prefix: Return value" );
    ok( $self->OK(), "$prefix: Created user with status " . $self->code() );
    is( $u->id(), $name, "$prefix: User is '$name'" );

    if( $func =~ /^define/ ) {
	if( defined $data{password} ) {
	    is( $u->password(), sha256_hex( $data{password} ), "$prefix: Password matches" );
	} else {
	    ok( length( $u->password() ) >= 12, "$prefix: Got random password" );
	}
    }
}

sub _check_relation {
    my $self = shift;
    my $r = shift;
    my %data = @_;

    my $name = $data{name};
    my $pkg  = $data{pkg};
    my $func = $data{func};

    my $prefix = "$pkg->$func()";

    isa_ok( $r, $Y_Re, "$prefix: Return value" );
    my $rname = $r->id();
    ok( $self->OK(), "$prefix: Created relation '$rname' with status " . $self->code() );

    if( defined $name ) {
	is( $name, $rname, "$prefix: Label is '$rname'" );
    }
}

sub _check_instance {
    my $self = shift;
    my $i = shift;
    my %data = @_;

    my $name = $data{name};
    my $func = $data{func};

    my $prefix = "$Y_E->$func()";

    isa_ok( $i, $Y_E_I, "$prefix: Return value" );
    ok( $self->OK(), "$prefix: $func()'ed instance '$name' with status " . $self->code() );

    my $n = $i->id();
    is( $n, $name, "$prefix: Instance id is $n" );
}

sub _check_property {
    my $self = shift;
    my $p = shift;
    my %data = @_;

    my $name = $data{name};
    my $e    = $data{entity};
    my $pkg  = $data{pkg};
    my $func = $data{func};

    my $prefix = "$pkg->$func()";

    isa_ok( $p, $Y_P, "$prefix: Return value" );
    ok( $self->OK(), "$prefix: Created property '$name' with status ".$self->code() );
    my $n = $p->id();
    is( $n, $name, "$prefix: Name is '$n'" );

    my $e_name = $e->id();
    my $fqn = join(":", $e_name, $name);
    my $fn = $p->full_name();
    is( $fn, $fqn, "$prefix: Full name is '$fn'" );

    my $pe = $p->entity();
    # FIX: $property->entiy() will one day return objects!
    #isa_ok( $pe, $Y_E, "$prefix: Owning entity" );
}

sub _check_entity {
    my $self = shift;
    my $e = shift;
    my %data = @_;

    my $name = $data{name};
    my $pkg  = $data{pkg};
    my $func = $data{func};

    my $prefix = "$pkg->$func()";

    isa_ok( $e, $Y_E, "$prefix: Return value" );
    ok( $self->OK(), "$prefix: Created entity '$name' with status ".$self->code() );

    my $n = $e->id();
    is( $n, $name, "$prefix: Name is '$name'" );
}

sub status {
    my $self = shift;

    return $self->{status} if $self->{status};

    my $s = $self->{ygg}->get_status();
    isa_ok( $s, $Y_S, "$Y->get_status(): return value" );

    return $self->{status} = $s;
}

sub OK {
    my $self = shift;

    return $self->status()->OK();
}

sub code {
    my $self = shift;

    return $self->status()->status();
}

1;
