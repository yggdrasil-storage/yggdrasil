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
# 		script   => [ 
# 			     {
# 			      language => 'javascript',
# 			      src      => 'yggdrasil.js',
# 			     },
# 			     {
# 			      language => 'javascript',
# 			      src      => 'http://ajax.googleapis.com/ajax/libs/jquery/1.3.2/jquery.min.js',
# 			     }
# 			    ],
# 		style    => [ { src => 'yggdrasil.css', }, ],
    };

    for my $key (keys %params) {
	$self->{$key} = $params{$key};
    }

    my $status = $self->{yggdrasil}->get_status();

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
    print <<"EOT";
<html>
  <script type="text/javascript" src="http://code.jquery.com/jquery-1.4.2.min.js"></script>
  <script type="text/javascript" src="iphone.js"></script>
  <script type="text/javascript" src="yggdrasil.js"></script>

  <link rel="stylesheet" type="text/css" 
	href="iphone.css" media="only screen and (max-width: 480px)" />
  <link rel="stylesheet" type="text/css" 
	href="desktop.css" media="screen and (min-width: 481px)" />            

  <meta name="apple-mobile-web-app-capable" content="yes" />
  <meta name="apple-mobile-web-app-status-bar-style" content="black" />

  <link rel="apple-touch-icon" href="phone.png" />
  <meta name="viewport" content="user-scalable=no, width=device-width" />
<!--[if IE]>
<link rel="stylesheet" type="text/css" href="desktop.css" media="all" />
<![endif]-->

  <title>$title</title>
</head>
<body>
<div id="container">
  <div id="header">
    <h1><a href="./">Yggdrasil</a></h1>
EOT
}

sub end {
    my $self = shift;
    my $cgi  = $self->{cgi};
    print "</div>\n";
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

    print <<"EOT";
<html>
  <link rel="stylesheet" type="text/css" 
	href="iphone.css" media="screen and (max-width: 480px)" />
  <link rel="stylesheet" type="text/css" 
	href="desktop.css" media="screen and (min-width: 481px)" />            

  <meta name="apple-mobile-web-app-capable" content="yes" />
  <meta name="apple-mobile-web-app-status-bar-style" content="black" />

  <script type="text/javascript" src="jquery.js"></script>
  <script type="text/javascript" src="iphone.js"></script>
  <script type="text/javascript" src="yggdrasil.js"></script>

  <link rel="apple-touch-icon" href="phone.png" />
  <meta name="viewport" content="user-scalable=no, width=device-width" />
<!--[if IE]>
<link rel="stylesheet" type="text/css" href="desktop.css" media="all" />
<![endif]-->

  <title>$title</title>
</head>
<body>
<div id="container">
<h1 class="login">Login to Yggdrasil</h1>
EOT

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
