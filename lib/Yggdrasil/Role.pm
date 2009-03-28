package Yggdrasil::Role;

# This class acts as a wrapper class for the entity MetaAuthRole.
# It provides a handy interface to defining, getting, undefining roles,
# as well as getters and setters for some predefined properties.

use strict;
use warnings;

use base qw(Yggdrasil::Object);

use Yggdrasil::Entity;

sub define {
    my $class = shift;
    my $self  = $class->SUPER::new(@_);
    my %params = @_;

    my $meta_role = Yggdrasil::Entity->get( yggdrasil => $self, entity => 'MetaAuthRole' );
    my $ro = $meta_role->create( $params{'role'});

    $self->{_role_obj} = $ro;

    return $self;
}

sub get {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    my $id = $params{id};

    my $e = Yggdrasil::Entity->get( yggdrasil => $self, entity => "MetaAuthRole" );
    my $ro = $e->fetch( $id );
    $self->{_role_obj} = $ro;

    return $self;
}

sub undefine {

}

sub members {
    # list all role members
}

sub name {
    # name of role
}


sub grant {
    my $self   = shift;
    my $schema = shift;
    my $grant  = shift;

    # Take either the name, or an object as a parameter.
    $schema = $schema->name() if ref $schema;

#    w => r+w
#    r => r
#    c => r+w+c
#    d => r+w+c+d

    my $read   = 0;
    my $write  = 0;
    my $create = 0;
    my $delete = 0;

    if( $grant =~ /c/ ) {
	$read   = 1;
	$write  = 1;
	$create = 1;
    }
    
    if( $grant =~ /d/ ) {
	$read   = 1;
	$write  = 1;
	$create = 1;
	$delete = 1;
    }

    if( $grant =~ /w/ ) {
	$read  = 1;
	$write = 1;
    }

    if( $grant =~ /r/ ) {
	$read = 1;
    }

    $self->_set_permissions( read => $read, write => $write,
			     delete => $delete, create => $create,
			     schema => $schema );
}

sub revoke {
    my $self   = shift;
    my $schema = shift;
    my $revoke = shift;

    # Take either the name, or an object as a parameter.
    $schema = $schema->name() if ref $schema;
    
#    w => r+w
#    r => r
#    c => r+w+c
#    d => r+w+c+d

    my $read   = 0;
    my $write  = 0;
    my $create = 0;
    my $delete = 0;

    if( $revoke =~ /c/ ) {
	$read   = 1;
	$write  = 1;
	$create = 0;
    }
    
    if( $revoke =~ /d/ ) {
	$read   = 1;
	$write  = 1;
	$create = 1;
	$delete = 0;
    }

    if( $revoke =~ /w/ ) {
	$read  = 1;
	$write = 0;
    }

    if( $revoke =~ /r/ ) {
	$read   = 0;
    }

    $self->_set_permissions( read => $read, write => $write,
			     delete => $delete, create => $create,
			     schema => $schema );
}

sub _set_permissions {
    my $self  = shift;
    my %param = @_;

    my $robj = $self->{_role_obj};
    my $storage = $self->{yggdrasil}->{storage};

    my @parts = split m/::/, $param{schema};
    my $last = pop @parts;
    my ($e, $p) = (split m/:/, $last, 2);
    push( @parts, $e );
    $e = join('::', @parts);
    
    # FIX: gah we don't get Host_ip on property ip, but only "ip"
    #      for the time being we "solve" this by checking for ... casing! YAY!
    if( $e !~ /^[A-Z]/ ) {
	# revoke rights for property access

	# FIX: we don't do properties yet, because we don't know what bloody entity we belong to
	return;

	my $ido = $storage->fetch( MetaProperty => { return => "id",
						     where  => [ property => $p,
								 entity   => \qq<MetaEntity.id> ]
						   },
				   MetaEntity => { where => [ entity => $e ] } );
	my $id = $ido->[0]->{id};

	$storage->store( "MetaAuthProperty",
			 key => [ qw/role property/ ],
			 fields => {
				    writeable => $param{write},
				    readable  => $param{read},
				    role      => $self->{_id},
				    property  => $id,
				   } );
	
	
    } else {
	# revoke rights for entity access
	my $ido= $storage->fetch( MetaEntity => { return => "id", where => [ entity => $e ] } );
	my $id = $ido->[0]->{id};

	Yggdrasil::fatal( "Unable to set access to entity '$e', no such entity!" ) unless $id;
	
	$storage->store( "MetaAuthEntity",
			 key => [ qw/role entity/ ],
			 fields => { 
				    deleteable => $param{delete},
				    createable => $param{create},
				    writeable  => $param{write},
				    readable   => $param{read},
				    role       => $robj->{_id},
				    entity     => $id,
				   } );
	
    } 

}

sub add {
    my $self = shift;
    my $user = shift;

    my $robj = $self->{_role_obj};
    my $uobj = $user->{_user_obj};

    $self->{yggdrasil}->{storage}->store( "MetaAuthRolemembership",
					  key => [ qw/role user/ ],
					  fields => { role => $robj->{_id},
						      user => $uobj->{_id},
						    } );    
}

sub remove {
    my $self = shift;
    my $user = shift;

    my $robj = $self->{_role_obj};
    my $uobj = $user->{_user_obj};

    $self->{yggdrasil}->{storage}->expire( "MetaAuthRolemembership",
					   role => $robj->{_id},
					   user => $uobj->{_id} );
}

1;
