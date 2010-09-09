package Yggdrasil::Interface::WWW;

use strict;
use warnings;

use CGI::Pretty qw/-debug/;

sub new {
    my $class = shift;
    my %params = @_;

    my $self = {
		elements => [],
		headers  => {},
		cgi      => CGI::Pretty->new(),
		script   => [ 
			     {
			      language => 'javascript',
			      src      => 'yggdrasil.js',
			     },
			     {
			      language => 'javascript',
			      src      => 'http://ajax.googleapis.com/ajax/libs/jquery/1.3.2/jquery.min.js',
			     }
			    ],
		style    => [ { src => 'yggdrasil.css', }, ],
		defaultmods => [ qw/Search Entities Instances / ],
    };

    for my $key (keys %params) {
	$self->{$key} = $params{$key};
    }

    my $status = $self->{yggdrasil}->get_status();
    
    if ($ENV{HTTP_USER_AGENT} && $ENV{HTTP_USER_AGENT} =~ /iphone/i) {
	$self->{style} = [ { src => 'iPhone.css', }, ]
    }

    my $file = join('.', join('/', split '::', __PACKAGE__), "pm" );
    my $path = $INC{$file};
    $path =~ s/\.pm$//;
    $path = join('/', "$path/Module");

    if (opendir( DIR, $path )) {
 	my $module;
	while ($module = readdir(DIR))  {
	    my $fqfile = "$path/$module";
	    next unless -f $fqfile && -r $fqfile;
	    next unless $module =~ s/\.pm$//;
	    my $module_class = join("::", __PACKAGE__, "Module", $module );
	    eval qq( require $module_class );
	    if ($@) {
		die( $@ );
	    }
	}
	closedir DIR;
    } else {
	$status->set( 503, "Unable to find modules under $path: $!");
	return undef;
    }
    
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

sub start {
    my $self = shift;
    my %param = @_;

    my $title  = $param{title};
    my $sheet  = $param{style}  || $self->{style};
    my $script = $param{script} || $self->{script};
    my $cgi    = $self->{cgi};
    
    print $cgi->header( %{ $self->{headers} } );
    print $cgi->start_html( -title  => $title,
			    -style  => $sheet,
			    -script => $script,
			  );
}

sub end {
    my $self = shift;
    my $cgi  = $self->{cgi};
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
			    -style  => $sheet,
			    -script => $script,
			  );
    
    print $cgi->start_form( -method => "POST" );
    print $cgi->table( {class=>"login"}, 
		       $cgi->TR( $cgi->td("username"), $cgi->td( $cgi->input( {type=>"text", name=>"user"} ) ) ),
		       $cgi->TR( $cgi->td("password"), $cgi->td( $cgi->input( {type=>"password", name=>"pass"} ) ) ),
		       $cgi->TR( $cgi->td( {colspan=>2}, $cgi->input( {type=>"submit",value=>"Login"} ) ) ) );
    print $cgi->hidden( { name=>"mode", value=>"about" } );
    print $cgi->end_form();
    print $cgi->end_html();
    
}

1;
