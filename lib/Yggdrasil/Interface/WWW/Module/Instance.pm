package Yggdrasil::Interface::WWW::Module::Instance;

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
		entity => $params{entity},
	       };

    return bless $self, $class;
}

sub display {
    my $self = shift;

#     print "$entity / $instance:\n";

#     printf "%-15s - ", "Permissions";
#     printf "Edit: %s / ", $iobj->can_write()?'Yes':'No';    
#     printf "Expire: %s\n", $iobj->can_expire()?'Yes':'No';    
    
#     my @props = $eobj->properties();
#     printf "%-15s - %s\n", 'Property', 'Value' if @props;
#     for my $prop (@props) {
# 	my $value = $iobj->get( $prop ) || '';
# 	my ($r, $w, $e)  = ('r',
# 			    $iobj->can_write_value( $prop )?'w':'',
# 			    $iobj->can_expire_value( $prop )?'e':'');
# 	if (length $value > 65) {
# 	    $value = substr( $value, 0, 60 ) . '[ ... ]';
# 	}
	
# 	printf "  %-13s - %s ($r$w$e)\n", $prop->id(), $value;
#     }

#     display_tick( $iobj );
    
}

1;
