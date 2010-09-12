package Yggdrasil::Interface::WWW::Module::Menu;

use strict;
use warnings;

use base 'Yggdrasil::Interface::WWW::Module';

use FindBin qw($Bin);
use lib qq($Bin/../lib);

sub new {
    my $class  = shift;
    my %params = @_;
    
    my $self = {};

    for my $key (keys %params) {
	$self->{$key} = $params{$key};
    }
    
    return bless $self, $class;
}

sub display {
    my $self = shift;
    my $user = $self->{www}->{userobj};
    my $username = $user->id();
    
    # Main headers.
    print <<EOT;
    <div id="utility">
        <ul>
            <li><a href="?mode=about">About</a></li>
            <li><a href="?mode=user">User</a></li>
            <li><a href="?mode=help">Help</a></li>
            <li><a href="?mode=logout">Log out</a></li>
            <li>
	      <form action="index.cgi" method="post">
		<input type="text" name="search" autocorrect="off"
		       placeholder="search" autocapitalize="off" id="searchbox">
	      </form>
	    </li>
        </ul>
    </div>
   </div> <!-- closes the header div -->
EOT
}

1;


