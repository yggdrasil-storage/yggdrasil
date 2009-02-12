package Yggdrasil::MetaAuth;

use strict;
use warnings;

use base qw(Yggdrasil::Meta);

use Yggdrasil::Entity;
use Yggdrasil::Property;

sub _define {
    my $self = shift;
    my %params = @_;
    $self->{yggdrasil} = $params{yggdrasil};
    $self->{storage}   = $params{yggdrasil}->{storage};
    
    # Temporality for free is nice.
    my $user = $self->define_entity( "MetaAuthUser" );
    $self->define_property( "MetaAuthUser:password", type => "PASSWORD" );
    $self->define_property( "MetaAuthUser:session", type => "TEXT" );

    my $role = $self->define_entity( "MetaAuthRole" );

    # --- Tell Storage to create SCHEMA, noop if it exists
    $self->{storage}->define( "MetaAuthProperty",
			      fields   => {
				  id       => { type => "SERIAL" },
				  property => { type => "INTEGER" },
				  role     => { type => "INTEGER" },
				  readable  => { type => "BOOLEAN" },
				  writeable => { type => "BOOLEAN" },
			      },
			      temporal => 1,
			      nomap    => 1,
			      hints    => {
				  property => { foreign => "MetaProperty" },
				  role     => { foreign => "MetaAuthRole" },
			      }
	);

    $self->{storage}->define( "MetaAuthEntity",
			      fields   => { 
				  id     => { type => "SERIAL" },
				  entity => { type => "INTEGER" },
				  role   => { type => "INTEGER" },
				  readable   => { type => "BOOLEAN" },
				  writeable  => { type => "BOOLEAN" },
				  createable => { type => "BOOLEAN" },
				  deleteable => { type => "BOOLEAN" },
			      },
			      temporal => 1,
			      nomap    => 1,
			      hints    => {
				  entity => { foreign => "MetaEntity" },
				  role   => { foreign => "MetaAuthRole" },
			      }
	);

    $self->{storage}->define( "MetaAuthRolemembership",
			      fields   => {
				  role => { type => "INTEGER" },
				  user => { type => "INTEGER" },
			      },
			      temporal => 1,
			      nomap    => 1,
			      hints    => {
				  role => { foreign => "MetaAuthRole" },
				  user => { foreign => "MetaAuthUser" },
			      }
	);
    return $self;
}

1;
