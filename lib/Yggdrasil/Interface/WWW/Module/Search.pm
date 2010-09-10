package Yggdrasil::Interface::WWW::Module::Search;

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

    $self->{search} = $self->{www}->param( 'search' );
    $self->{ygg}    = $self->{www}->{yggdrasil};

    return bless $self, $class;
}

sub display {
    my $self = shift;
    
    my $cgi = $self->{www}->{cgi};

    # Idea; if we get one exact hit, return the loosly matching stuff
    # as a list ala the menu, but give the single exact match a proper
    # showing.  If we get multiple exact matches (instance and entity
    # with the exact id() as the search string, show them as the first
    # hits.

    if ($self->{search}) {
	my $ygg = $self->{ygg};
	my ($eref, $iref, $pref, $rref) = $ygg->search( $self->{search} );

	print "<div class='searchhits'>\n";
	if (@$eref || @$iref || @$pref || @$rref) {
	    my (@hits, @exacts);
	    for my $o (@$eref, @$iref, @$pref, @$rref) {
		my $id = $o->id();

		my $type = $self->get_type( $o );
		my $displaytype = $type;
		
		my $entitystring = '';
		if ($type eq 'instance') {
		    my $entityid = $o->entity()->id();
		    $entitystring = ";entity=$entityid";
		    $displaytype = "instance in <a href='?entity=$entityid'>$entityid</a>";
		}
		
		my $string = $cgi->p( { class => "searchhit_$type" },
				      $cgi->a( { href => "?$type=$id" . $entitystring }, $id ),
				      " ($displaytype) ", 
				      $cgi->br(),
				      $cgi->span( {class => 'searchinfo' }, $self->tick_info( $o, 'inline' ) ),
				    );		
		
		if ($id eq $self->{search}) {
		    push @exacts, $string;
		} else {
		    push @hits, $string;
		}
	    }

	    print $cgi->div( { class => 'searchhit_exact' }, @exacts ) if @exacts;
	    print $cgi->div( { class => 'searchhit_normal' }, @hits )  if @hits;
	} 
	print "</div>\n";
	
    } 
    
}

1;
