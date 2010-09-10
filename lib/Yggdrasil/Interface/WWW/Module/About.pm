package Yggdrasil::Interface::WWW::Module::About;

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

    my $cgi = $self->{www}->{cgi};
    my $ygg = $self->yggdrasil();

    my $static_path = $self->static_dir_path();
    
    print '<div class="about">';
    if (open FILE, "$static_path/About.html") {
	print while (<FILE>);
	close FILE;
    } 
    
    print $cgi->p( "This yggdrasil installation runs version " . $ygg->version(),
		   " and the data is stored by a " . $ygg->info(),
		   "The current Yggdrasil tick is " . $ygg->current_tick() . '.',
		   $ygg->is_remote()?$cgi->br() . join(",", $ygg->server_data()):'',
		   $ygg->is_remote()?"Running time: " . $ygg->uptime(). $cgi->br():''
		 );
    print "</div>\n";
}


1;
