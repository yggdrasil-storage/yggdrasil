package Yggdrasil::MetaAuth;

use strict;
use warnings;

use base qw(Yggdrasil::Meta);

use Yggdrasil::Entity;
use Yggdrasil::Property;

sub _define {
    my $self = shift;

    my $user = define Yggdrasil::Entity "MetaAuthUser";
    define Yggdrasil::Property $user, "password", type => "PASSWORD";
    define Yggdrasil::Property $user, "session", type => "TEXT";

    my $role = define Yggdrasil::Entity "MetaAuthRole";

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
}

1;
