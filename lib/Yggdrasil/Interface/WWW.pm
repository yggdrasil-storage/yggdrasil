package Yggdrasil::Interface::WWW;

use Yggdrasil::Interface::WWW::Container;

use strict;
use warnings;

use CGI::Pretty;

sub new {
    my $class = shift;

    my $self = {
		elements => [],
		headers  => {},
		cgi      => CGI::Pretty->new(),
		script   => 'yggdrasil.js',
		style    => 'yggdrasil.css',
    };

    return bless $self, $class;
}

sub param {
    my $self = shift;

    return $self->{cgi}->param(@_);
}

sub cookie {
    my $self = shift;

    return $self->{cgi}->cookie(@_);
}

sub add_header {
    my $self = shift;
    my $header = shift;
    my $value = shift;

    $self->{headers}->{$header} = $value;
}

sub set_session {
    my $self = shift;
    my $session = shift;

    my $cgi = $self->{cgi};
    my $cookie = $cgi->cookie(
	-name    => "sessionID",
	-value   => $session,
	-expires => '+48h'
	);

    $self->add_header( "-cookie", $cookie );
}

sub add {
    my $self = shift;
    my $container = new Yggdrasil::Interface::WWW::Container;
    
    $container->add( @_ );
    push @{ $self->{elements} }, $container;
    return $container;
}

sub display {
    my $self = shift;
    my %param = @_;

    my $title  = $param{title};
    my $sheet  = $param{style}  || $self->{style};
    my $script = $param{script} || $self->{script};

    my $cgi = $self->{cgi};

    print $cgi->header( %{ $self->{headers} } );
    print $cgi->start_html( -title  => $title,
			    -style  => { src => $sheet },
			    -script => {
					language => 'javascript',
					src      => $script,
				       },
			    
	);

    foreach my $container (@{ $self->{elements} }) {
	print $container->display( $self->{cgi} );
    }

    print $cgi->end_html();
}

sub present_login {
    my $self = shift;
    my %param = @_;

    my $title  = $param{title};
    my $sheet  = $param{style} || $self->{style};
    my $script = $param{script} || $self->{script};
    
    my $cgi = $self->{cgi};

    print $cgi->header();
    print $cgi->start_html( -title  => $title,
			    -style  => { src => $sheet },
			    -script => {
					language => 'javascript',
					src      => $script,
				       },
	);
    
    print $cgi->start_form( -method => "POST" );
    print $cgi->table( {class=>"login"}, 
		       $cgi->TR( $cgi->td("username"), $cgi->td( $cgi->input( {type=>"text", name=>"user"} ) ) ),
		       $cgi->TR( $cgi->td("password"), $cgi->td( $cgi->input( {type=>"password", name=>"pass"} ) ) ),
		       $cgi->TR( $cgi->td( {colspan=>2}, $cgi->input( {type=>"submit",value=>"Login"} ) ) ) );
    print $cgi->end_form();
    print $cgi->end_html();
    
}


1;
