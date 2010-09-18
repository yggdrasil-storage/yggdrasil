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

    return bless $self, $class;
}

sub display {
    my $self = shift;
    my $cgi  = $self->{www}->{cgi};

    my $ename = $self->{www}->{cgi}->param( 'entity' );
    
    return unless $ename;
    return if $cgi->param( 'instance' );

    my $ygg = $self->yggdrasil();

    my $entity;
    my $newentity = $cgi->param( 'newentity' );
    if ($newentity) {
	$entity = $ygg->define_entity( $newentity, inherit => $ename );
    } else {
	$entity = $ygg->get_entity( $ename );
    }

    my $action = $cgi->param( 'action' );
    if ($action eq 'expire') {
	my $name = $entity->id();
	$entity->expire();
	print $cgi->h1( "$name is expired" );
	return;
    }
    
    unless ($entity) {
	$self->error( $ygg->get_status()->message() );
	return;
    }

    my $can_write = $entity->can_write();
    my $can_expire = $entity->can_expire();
    my $can_instanciate = $entity->can_instanciate();
    my $can_subclass = $entity->can_create_subentity();
    
    my ($expire_code, $instanciate_code) = ('', '');
    if ($can_expire) {
	$expire_code = $self->expire( "entity=" . $entity->id(), ' ' );
    }

    if ($can_instanciate) {
	$instanciate_code  = '<form method="post" action="index.cgi" enctype="multipart/form-data" id="eiform" name="niform">';
	$instanciate_code .= "<input type='hidden' name='entity' value='" . $entity->id() . "' />\n";
	$instanciate_code .= $cgi->hidden( { name => 'entity', value => 'Daille::Foo' } );
	$instanciate_code .= $cgi->hidden( { name => 'create', value => 1 } );
	$instanciate_code .= $cgi->input( { type => "text", name  => "instance", autocorrection => 'off',
					    class => 'iform', autocapitalize => 'off', placeholder => 'new instance' } );
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

    $self->create_property( $entity ) if $self->{www}->{cgi}->param( 'create' );

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
		   $cgi->td( $cgi->input( { type => "text", name => "property",  autocorrection => 'off',
					    autocapitalize => 'off', placeholder => 'property' } ) ),
		   $cgi->td( $cgi->popup_menu( -name=> 'type', -values=> \@types )),
		   $cgi->td( $cgi->popup_menu( -name=> 'null', -values=> [ qw/Yes No/ ] )),
		   $cgi->td( $cgi->submit( { type => "submit", value => "Create" }, 'Create' ) ),
		  );
    }

    if (@propdisplay) {
	if ($can_write) {
	    print '<form method="post" action="index.cgi" enctype="multipart/form-data" id="epform" name="propform">';
	    print "<input type='hidden' name='entity' value='" . $entity->id() . "' />\n";
	    print $cgi->hidden( { name => 'create', value => 1 } );
	}
	
	print $cgi->table(
			  { class => 'properties' },
			  $cgi->TR( $cgi->td( 'Name' ), $cgi->td( 'Type' ), $cgi->td( 'Null allowed' ), $cgi->td( 'Source' )),
			  @propdisplay,
			 );
	print $cgi->end_form() if $can_write;
    }

    if ($can_subclass) {
	print $cgi->h2( 'Create subentity' );
	print '<form method="post" action="index.cgi" enctype="multipart/form-data" id="ecform" name="ecform">';
	print "<input type='hidden' name='entity' value='" . $entity->id() . "' />\n";
	print $cgi->hidden( { name => 'create', value => 1 } );
	print $cgi->input( { type => "text", name => "newentity", autocorrection => 'off',
			     class => 'iform', autocapitalize => 'off', placeholder => 'new subentity' } );
	print $cgi->end_form();
    }
    
    print $self->tick_info( $entity );
}

sub create_property {
    my $self   = shift;
    my $e      = shift;
    my $www    = $self->{www};
    
    my ($property_name, $type, $null) = ($www->param( 'property'), $www->param( 'type' ), $www->param( 'null' ) );

    return unless ( $property_name && $type && $null );

    return $e->define_property( $property_name, type => uc $type, nullp => $null eq 'YES'?0:1 );
}

1;
