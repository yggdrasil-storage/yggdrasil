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

    my $file = join('.', join('/', split '::', __PACKAGE__), "pm" );
    my $path = $INC{$file};
    $path =~ s/\.pm$/.html/;

    my $cgi = $self->{www}->{cgi};
    my $ygg = $self->yggdrasil();
    
    if (open FILE, $path) {
	print while (<FILE>);
	close FILE;
    } 

    print $cgi->p( { class => 'about' }, "This yggdrasil installation runs version " . $ygg->version(),
		   $cgi->br(),
		   "Server: " . $ygg->info(),
		   $cgi->br(),
		   "Uptime: " . $ygg->uptime(),
		   $cgi->br(),
		   "The current Yggdrasil tick is: " . $ygg->current_tick(),
		   $cgi->br(),
		   $ygg->is_remote?join(",", $ygg->server_data()):'',
		 );
}


1;
