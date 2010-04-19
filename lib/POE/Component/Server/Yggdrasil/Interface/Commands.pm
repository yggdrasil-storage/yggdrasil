package POE::Component::Server::Yggdrasil::Interface::Commands;

use warnings;
use strict;


sub new {
    my $class = shift;
    my %params = @_;
    my $y = $params{yggdrasil};

    my $self = {	
		# define_entity   => sub { _define_entity( $y, @_ ) },
		# define_property => sub { _define_property( $y, @_ ) },

		get_entity      => sub { _get_entity( $y, @_ ) },
		get_instance    => sub { _get_instance( $y, @_ ) },
		get_value       => sub { _get_value( $y, @_ ) },
		# ...
	       };  
  

    return bless $self, $class;
}

sub _get_entity {
    my $ygg = shift;
    my %params = @_;
    
    return $ygg->get_entity( $params{entityid} );
}

sub _get_instance {
    my $ygg = shift;
    my %params = @_;
    
    my $entity = $ygg->get_entity( $params{entityid} );

    return undef unless $entity;
    return $entity->fetch( $params{instanceid} );
}

sub _get_value {
    my $ygg = shift;
    my %params = @_;
    
    my $entity = $ygg->get_entity( $params{entityid} );

    return undef unless $entity;
    my $instance = $entity->fetch( $params{instanceid} );
    
    return undef unless $instance;
    return ($instance->property( $params{propertyid} ), $instance);
}


1;
