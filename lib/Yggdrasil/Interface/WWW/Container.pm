package Yggdrasil::Interface::WWW::Container;

use strict;
use warnings;

sub new {
    my $class = shift;

    my $self = {
	elements => [],
	type     => undef,
        id       => undef,
	class    => undef,
    };

    return bless $self, $class;
}

sub add {
    my $self = shift;

    push @{ $self->{elements} }, @_;
}

sub type {
    my $self = shift;
    my $type = shift;

    $self->{type} = $type if $type;
    return $self->{type};
}

sub id {
    my $self = shift;
    my $id   = shift;

    $self->{id} = $id if $id;
    return $self->{id};
}

sub class {
    my $self  = shift;
    my $class = shift;

    $self->{class} = $class if $class;
    return $self->{class};
}

sub parent {
    my $self  = shift;
    my $parent = shift;

    $self->{parent} = $parent if $parent;
    return $self->{parent};
}

sub display {
    my $self = shift;
    my $cgi  = shift;

    my %attr;
    if( $self->id() ) {
	$attr{id} = $self->id();
    }

    if( $self->class() ) {
	$attr{class} = $self->class();
    }

    my $title = $self->parent() || $self->type();

    my @elems; 

    foreach my $e ( sort @{ $self->{elements} } ) {
	if( $self->type() eq "Entities" ) {
	    push( @elems, $cgi->li( $cgi->a( {href => "?_mode=entity;_identifier=$e" }, $e ) ) );
	} elsif( $self->type() eq "Relations" ) {
	    push( @elems, $cgi->li( $cgi->a( {href => "?_mode=relation;_identifier=$e" }, $e ) ) );
	} elsif( $self->type() eq "Entity" ) {
	    push( @elems, $cgi->li( $cgi->a( {href => "?_mode=instance;_identifier=$e;_entity=" . $self->parent() }, $e ) ) );
	    
	    $title = join(":: ", $cgi->a( {href=>"./"}, "Yggdrasil" ), $self->parent() || $self->type());
	} elsif( $self->type() eq "Instance" ) {

	    my $entity = delete $e->{_entity};
	    my $instance = delete $e->{_instance};
	    my $id = delete $e->{_id};

	    $title = join(":: ", $cgi->a( {href=>"./"},"Yggdrasil" ), $cgi->a( {href=>"?_mode=entity;_identifier=$entity"}, $entity ), $instance);
	    my @row_classes = ( "odd", "even" );

	    my $value = $e->{value};

	    if( defined $e->{access} && $e->{access} eq "write" ) {
		$value = $cgi->input( { type => "text", name => $id, value => $value } );
	    } 

	    push( @elems, $cgi->TR( { class => $row_classes[ @elems % 2 ] }, $cgi->td( $id ), $cgi->td( $value ) ) );
	} elsif( $self->type() eq "Related" ) {

	    my $entity = delete $e->{_entity};
	    my $instance = delete $e->{_instance};
	    my $id = delete $e->{_id};

	    my @row_classes = ( "odd", "even" );

	    my $value = join(", ", map { $cgi->a( {href=>"?_mode=instance;_entity=$id;_identifier=".$_->id() }, $_->id() ) } @{ $e->{value} });
	    $id = $cgi->span( {class => "relation" }, $cgi->a( {href=>"?_mode=entity;_identifier=$id"}, $id ) );

	    if( defined $e->{access} && $e->{access} eq "write" ) {
		$value = $cgi->input( { type => "text", name => $id, value => $value } );
	    }

	    push( @elems, $cgi->TR( { class => $row_classes[ @elems % 2 ] }, $cgi->td( $id ), $cgi->td( $value ) ) );

	}
    }

    if( $self->type() eq "Instance" || $self->type() eq "Related") {
	return $cgi->div( \%attr, $cgi->h1($title), $cgi->table( { class => $self->class() }, @elems ) );
    } else {
	return $cgi->div( \%attr, $cgi->h1($title), $cgi->ul(@elems) );
    }


}

1;
