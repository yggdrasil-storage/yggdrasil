package Yggdrasil::Interface::WWW::Module;

use strict;
use warnings;

use FindBin qw($Bin);
use lib qq($Bin/../lib);

sub nameify {
    my $self = shift;
    my $obj = shift;
    
    if ($obj->stop()) {
        return $obj->id() . ':' . $obj->start() . '-' . $obj->stop();
    } else {
        return $obj->id();
    }
}

sub get_type {
    my $self = shift;
    my $object = shift;

    my $type = (split /::/, ref $object)[-1];
    return lc $type;
}

sub tick_info {
    my $self   = shift;
    my $obj    = shift;
    my $inline = shift;
    my $y    = $self->yggdrasil();
    
    my $tick = $y->get_tick( $obj->start() );
    my $string = sprintf "%s %s (tick %d) by %s ", 'Created', $tick->{stamp}, $obj->start(), $tick->{committer};

    if ($obj->stop()) {
        $tick = $y->get_tick( $obj->stop() );
        $string .= sprintf ", %s %s (tick %d) by %s ", 'Expired', $tick->{stamp}, $obj->stop(), $tick->{committer};
    }

    if ($inline) {
	return $string;
    } else {
	return $self->{www}->{cgi}->div( { class => 'tickinfo' }, $string );	
    }
    
}

sub yggdrasil {
    my $self = shift;
    return $self->{www}->{yggdrasil};
}

sub error {
    my $self   = shift;
    my $string = shift;
    print $self->{www}->{cgi}->div( { class => 'error' }, $string );
}

sub info {
    my $self   = shift;
    my $string = shift;
    print $self->{www}->{cgi}->div( { class => 'info' }, $string );
}

sub expire {
    my $self   = shift;
    my $target = shift;
    my $no_line_break = shift;

    my $cgi = $self->{www}->{cgi};
    return $cgi->span( { class => 'expiretext' },
		       $no_line_break?$no_line_break:$cgi->br(),
		       $cgi->a( { href => "?$target;action=expire" }, ' (expire)' ));
}

sub static_dir_path {
    my $self = shift;
    
    my $file = join('.', join('/', split '::', __PACKAGE__), "pm" );
    my $path = $INC{$file};
    $path =~ s|Module.pm$|static|;
    return $path;
}

1;
