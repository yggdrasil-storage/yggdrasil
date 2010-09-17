package Yggdrasil::Interface::WWW::Module::Binary;

use strict;
use warnings;

use File::Type;
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
    my $www  = $self->{www};

    my $ename = $www->param( 'entity' );
    my $iname = $www->param( 'instance' );
    my $pname = $www->param( 'property' );

    unless ($ename && $iname && $pname) {
	$self->error( join ", ", $www->{cgi}->Vars() );
	exit;
    }

    my $ygg = $self->yggdrasil();

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
    
    my $data = $instance->get( $pname );
    unless ($ygg->get_status()->OK()) {
	$self->error( $ygg->get_status()->message() );
	return;	
    }

    unless (defined $data) {
	$self->error( 'No content' );
	return;
    }

    my $ft = File::Type->new();
    my $type = $ft->mime_type( $data );

    my $ext = $type;
    $ext =~ s|^.*/||;
    
    print $www->{cgi}->header( -type => $type, '-Content_disposition' => "attachment; filename=download.$ext" );
    print $data;
}



sub error {
    my $self = shift;
    my $msg  = shift;

    # Make HTML headers, print error with SUPER::error;
    $self->{www}->start( title => 'Error!' );
    $self->SUPER::error( $msg );
    $self->{www}->end();
}

1;
