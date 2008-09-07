package Yggdrasil::Plugin::Shared;

use strict;
use warnings;

sub new {
    my $class = shift;
    my $self  = {@_};

    return bless $self, $class;
}

sub namespace {
    my $self = shift;
    my $ns   = shift;

    $self->{namespace} = $ns;
}

sub entities {
    my $self = shift;

    return Yggdrasil::entities();
}

sub relations {
    my $self = shift;

    return Yggdrasil::relations();
}

sub instances {
    my $self = shift;
    my $entity = shift;

    my $package = join("::", $self->{namespace}, $entity);

    return $package->instances();
}

sub instance {
    my $self = shift;
    my $entity = shift;
    my $ident = shift;

    my $package = join("::", $self->{namespace}, $entity);
    my $instance = $package->get($ident);

    my @p;
    foreach my $prop ( $instance->properties() ) {

	my $v = { property  => $prop, 
		  value     => $instance->property($prop),
		  _entity   => $entity,
		  _instance => $ident,
		  _id       => $prop,
	};

	push( @p, $v );
    }

    return @p;
}

sub related {
    my $self = shift;
    my $entity = shift;
    my $ident = shift;

    my $package = join("::", $self->{namespace}, $entity);
    my $instance = $package->get($ident);

    my @p;

    foreach my $e ( $self->entities() ) {
	next if $e eq $entity;

	my @o = $instance->fetch_related( $e );
	
	push( @p, { property  => $e,
		    value     => \@o,
		    _entity   => $entity,
		    _instance => $ident,
		    _id       => $e,
	      } );
    }

    return @p;
}

1;
