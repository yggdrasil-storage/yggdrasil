package POE::Component::Server::Yggdrasil::Interface::Commands;

use warnings;
use strict;


sub new {
    my $class = shift;
    my %params = @_;
    my $y = $params{yggdrasil};
    
    my $self = {		
		define_entity   => sub{ $y->define_entity( @_ ) },
		define_property => sub{ $y->define_property( @_ ) },
		get_entity      => sub{ $y->get_entity( @_ ) },
		# ... 
	       };  
  
    bless $self, $class;

    return $self;
}

1;
