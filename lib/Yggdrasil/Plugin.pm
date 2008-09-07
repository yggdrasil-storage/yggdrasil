package Yggdrasil::Plugin;

use strict;
use warnings;

use UNIVERSAL qw(can);

use Yggdrasil;

our $AUTOLOAD;

sub new {
    my $class = shift;
    my $self  = {};

    bless $self, $class;
    $self->_init(@_);

    return $self;
}

sub _init {
    my $self = shift;
    my %data = @_;

    $self->{namespace} = $data{namespace};
    $self->{plugins}   = [];
    
    new Yggdrasil (%data);
}

sub add {
    my $self = shift;
    my @ps   = @_;
    
    foreach my $plugin ( @ps ) {
	$plugin->namespace( $self->{namespace} );
    }

    push( @{ $self->{plugins} }, @ps );
}

sub plugins {
    my $self = shift;

    return @{ $self->{plugins} };
}

sub AUTOLOAD {
    my $self = shift;
    my $meth = $AUTOLOAD;

    $meth =~ s/^.*:://;

    my %result;
    my %map;
    my $can;
    foreach my $plugin ( $self->plugins() ) {
	if( can $plugin, $meth ) {
	    foreach my $r ( $plugin->$meth(@_) ) {
		if( ref $r ) {
		    my $id = $r->{_id};
		    $result{$id}++;

		    #print ref $plugin, ": [$meth] -> $id processed $result{$id} times\n";

		    my $nv = $map{$id} || {};
		    
		    $nv->{$_} = $r->{$_} for keys %$r;

		    $map{$id} = $nv;
		} else {
		    $result{$r}++;
		    $map{$r} = $r;
		}
	    }
	    $can++;
	}
    }

    return map { $result{$_}==$can?$map{$_}:() } keys %result;
}

1;
