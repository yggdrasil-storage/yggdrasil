package Yggdrasil::Auth::Role;

use strict;
use warnings;

use base qw(Yggdrasil::Entity::Instance);

sub grant {
    my $self   = shift;
    my $schema = shift;
    my $grant  = shift;

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

    my $storage = $self->{yggdrasil}->{storage};
    
    my($e, $p) = split ':', $param{schema}, 2;
    
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
				    role       => $self->{_id},
				    entity     => $id,
				   } );
	
    } 

}

sub add {
    my $self = shift;
    my $user = shift;

    $self->{yggdrasil}->{storage}->store( "MetaAuthRolemembership",
					  key => [ qw/role user/ ],
					  fields => { role => $self->{_id},
						      user => $user->{_id},
						    } );
}

sub remove {
    my $self = shift;
    my $user = shift;

    $self->{yggdrasil}->{storage}->expire( "MetaAuthRolemembership",
					   role => $self->{_id},
					   user => $user->{_id} );
}

1;
