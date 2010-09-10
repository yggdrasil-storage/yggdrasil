package Yggdrasil::Interface::WWW::Module::User;

use strict;
use warnings;

use FindBin qw($Bin);
use lib qq($Bin/../lib);

use base 'Yggdrasil::Interface::WWW::Module';

sub new {
    my $class  = shift;
    my %params = @_;
    
    my $self = {
                www    => $params{www},
               };

    return bless $self, $class;
}

sub display {
    my $self = shift;
    
    my $ygg  = $self->yggdrasil();
    my $cgi  = $self->{www}->{cgi};
    my $arg  = $self->{www}->param( 'user' );
    # Default to showing the current user().
    my $user = $ygg->user();
    $user    = $ygg->get_user( $arg || $user );

    unless ($user) {
	$self->error( $ygg->get_status()->message() );
	return;	
    }

    print $cgi->h1( $user->id() );

    my $roles = join ", ", map { '<a href="?role=' . $_->id() . '">' . $_->id() . '</a>' } $user->member_of();

    print $cgi->table(
		      $cgi->TR( $cgi->td( 'Username' ),  $cgi->td( $user->id()) ),
		      $cgi->TR( $cgi->td( 'Full name' ), $cgi->td( $user->fullname()) ),
		      $cgi->TR( $cgi->td( 'Session' ),   $cgi->td( $user->session()) ),
		      $cgi->TR( $cgi->td( 'Roles' ),     $cgi->td( $roles ) ),
		     );

    $self->tick_info( $user );
}


1;

