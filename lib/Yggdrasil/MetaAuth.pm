package Yggdrasil::MetaAuth;

use strict;
use warnings;

use base qw(Yggdrasil::Object);

use Yggdrasil::Entity;
use Yggdrasil::Property;

sub define {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;
    $self->{storage}   = $params{yggdrasil}->{storage};
    
    # Temporality for free is nice.
    my $user = Yggdrasil::Entity->define( yggdrasil => $self, entity => "MetaAuthUser" );
    $user->define_property( "password", type => "PASSWORD" );
    $user->define_property( "session", type => "TEXT" );
    $user->define_property( "fullname", type => "TEXT" );
    my $role = Yggdrasil::Entity->define( yggdrasil => $self, entity => "MetaAuthRole" );
    $role->define_property( "name", type => "TEXT" );

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
