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
    my $self = shift;
    my $obj  = shift;
    my $y    = $self->{ygg};
    
    my $tick = $y->get_tick( $obj->start() );
    my $string = sprintf "%s %s (tick %d) by %s ", 'Created', $tick->{stamp}, $obj->start(), $tick->{committer};

    if ($obj->stop()) {
        $tick = $y->get_tick( $obj->stop() );
        $string .= sprintf ", %s %s (tick %d) by %s ", 'Expired', $tick->{stamp}, $obj->stop(), $tick->{committer};
    }
    return $string;
}

1;
