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
    my $ename = $self->{www}->param( 'entity' );
    my $iname = $self->{www}->param( 'instance' );

    return unless $ename && $iname;

    my $ygg = $self->yggdrasil();
    my $cgi = $self->{www}->{cgi};
    
    my $entity = $ygg->get_entity( $ename );
    unless ($entity) {
	$self->error( $ygg->get_status()->message() );
	return;
    }

    my $instance = $entity->fetch( $iname );
    unless ($instance) {
	$self->error( $ygg->get_status()->message() );
	return;
    }

    my $can_write = 1; #$entity->can_write();
    my $can_expire = $entity->can_expire();

    my $expire_code;
    if ($can_expire || 1) {
	$expire_code = $self->expire( "entity=$ename;instance=$iname" );
    }

    print $cgi->h1( $cgi->a( { href => "?entity=$ename" }, $ename ) . ' // ' . $iname, $expire_code );

    my @props = $entity->properties();

    my (@proplist, $needform);
    # We need a has_value, loading a multi-MB PDF into memory to see
    # if the value is set is...  Not good.
    for my $prop (@props) {
	my $value = $instance->get( $prop ) || '';	    
	my $can_write = $instance->can_write_value( $prop );
	$needform++ if $can_write;
	
	if (lc $prop->type() eq 'binary') {
	    $value .= $cgi->a( { href => "?mode=binary;entity=$ename;instance=$iname;property=" . $prop->id() }, 'view' ) if $value;
	    $value .= $cgi->input( { type => "file", name  => $prop->id() } );
	} else {
	    $value = $cgi->input( { type => "text", name  => $prop->id(), value => $value } ) if $can_write;
	}

	if ($instance->can_expire_value( $prop )) {
	    $value .= $self->expire( "entity=$ename;instance=$iname;property=" . $prop->id(), ' ' );
	}
	
	push @proplist, $cgi->TR(
				 $cgi->td( $prop->id() ),
				 $cgi->td( $value ),
				);	
    }

    print $cgi->start_form( -method => "POST", -action => 'index.cgi' ) if $needform;
    print $cgi->table( @proplist );
    print $cgi->submit( { type => "submit", value => "Update values" } );
    print $cgi->end_form() if $needform;
    
    print $self->tick_info( $instance );
}

1;
