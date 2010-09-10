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
<div id="menu">
 <a href="?mode=entities" class="menulink" id="entitylink">Structure</a> |
 <a href="?mode=user" class="menulink" id="usernamelink">$username</a> |
 <a href="?mode=help" class="menulink" id="helplink">Help</a> |
 <a href="?mode=about" class="menulink" id="aboutlink">About</a> |
 <a href="?mode=logout" class="menulink" id="logoutlink">Logout</a> 
</div>
EOT
    
    my $cgi = $self->{www}->{cgi};
    print $cgi->div( { id => 'search' },
		     $cgi->start_form( { id => 'searchform' }, -method => "POST", -action => 'index.cgi' ),
		     $cgi->input( { type => "text",   name  => "search", id => 'searchfield' } ),
		     $cgi->popup_menu( -name=> 'searchtarget',
				       -values=>[ 'Structure','Structure and Data','Data only']),
		     $cgi->submit( { type => "submit", value => "Search"} ),
		     $cgi->end_form(),
		   );
}

1;


