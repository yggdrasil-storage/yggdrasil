package Yggdrasil::Interface::WWW::Module::Entity;

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

    $self->{entity} = $self->{www}->{cgi}->param( 'entity' );
    
    return bless $self, $class;
}

sub display {
    my $self = shift;
    my $cgi  = $self->{www}->{cgi};

    return unless $self->{entity};
    return if $cgi->param( 'instance' );
    
    my $ygg = $self->yggdrasil();

    my $entity = $ygg->get_entity( $self->{entity} );
    
    unless ($entity) {
	$self->error( $ygg->get_status()->message() );
	return;
    }

    my $can_write = 1; #$entity->can_write();
    my $can_expire = $entity->can_expire();
    my $can_instanciate = $entity->can_instanciate();

    my ($expire_code, $instanciate_code) = ('', '');
    if ($can_expire || 1) {
	$expire_code = $self->expire( "entity=" . $entity->id() );
    }

    if ($can_instanciate) {
	$instanciate_code  = $cgi->start_form( { id => 'instanciate' }, -method => "POST", -action => 'index.cgi' );
	$instanciate_code .= 'Create new instance ';
	$instanciate_code .= $cgi->input( { type => "text", name  => "instance", class => 'iform' } );
	$instanciate_code .= $cgi->submit( { type => "submit", value => "OK", name => 'isubmit', class => 'iform' }, 'Create Instance' );
	$instanciate_code .= $cgi->end_form();
    }
    
    print $cgi->h1( $entity->id(), $expire_code );

    print $cgi->h2( 'Instances' );

    my @instances = $entity->instances();
    my $content = join (", ", map { $cgi->a( { href => "?entity=" . $entity->id() . ";instance=" . $self->nameify( $_ ) },
					     $self->nameify( $_ )) } @instances );
    print $cgi->div(
		    { class => 'instances' },
		    $content || 'None',
		   );

    print $cgi->div(
		    { class => 'createinstance' },
		    $instanciate_code,
		   );


    my @props = $entity->properties();
    print $cgi->h2( 'Properties' );

    my @propdisplay;
    if (@props) {
	for my $prop (@props) {
	    my $prop_orig_entity = $prop->entity();
	    my $source = $prop_orig_entity->id();
	    my $type = $prop->type();

	    push @propdisplay, $cgi->TR(
					$cgi->td( $self->nameify( $prop) ),
					$cgi->td( lc $prop->type() ),
					$cgi->td( $prop->null()?'Yes':'No' ),
					$cgi->td( $source ne $entity->id()?$cgi->a( { href => "?entity=$source" }, $source ):'' ),
				       );
	}

    }
    
    if ($can_write) {
	my @types = map { ucfirst lc $_ } $ygg->property_types();
	push @propdisplay,
	  $cgi->TR(
		   $cgi->td( $cgi->input( { type => "text", name  => "name" } ) ),
		   $cgi->td( $cgi->popup_menu( -name=> 'type', -values=> \@types )),
		   $cgi->td( $cgi->popup_menu( -name=> 'null', -values=> [ qw/Yes No/ ] )),
		   $cgi->td( $cgi->submit( { type => "submit", value => "Create" }, 'Create' ) ),
		  );
    }

    if (@propdisplay) {
	print $cgi->start_form( { id => 'propertycreate' }, -method => "POST", -action => 'index.cgi' ) if $can_write;
	print $cgi->table(
			  { class => 'properties' },
			  $cgi->TR( $cgi->td( 'Name' ), $cgi->td( 'Type' ), $cgi->td( 'Null allowed' ), $cgi->td( 'Source' )),
			  @propdisplay,
			 );
	print $cgi->end_form() if $can_write;
    }
    
    print $self->tick_info( $entity );
}

1;
