package Yggdrasil;

use strict;
use warnings;
use v5.006;

use Carp;

use Yggdrasil::MetaEntity;
use Yggdrasil::MetaProperty;
use Yggdrasil::MetaRelation;
use Yggdrasil::MetaInheritance;

use Yggdrasil::Storage;
use Yggdrasil::Entity;
use Yggdrasil::Relation;
use Yggdrasil::Property;

our $VERSION = '0.01';

our $STORAGE;
our $NAMESPACE;

sub new {
    my $class = shift;

#    print "CLASS = $class\n";
#    use Carp qw/cluck/;
#    cluck();

    my $self  = bless {}, $class;

    $self->_init(@_);
    
    return $self;
}

sub _init {
    my $self = shift;
    
    if( ref $self eq __PACKAGE__ ) {
	my %params = @_;
	$self->{namespace} = $NAMESPACE = $params{namespace} || '';
	$self->{storage} = $STORAGE = Yggdrasil::Storage->new(@_);

	die "No storage layer initalized, aborting.\n" unless $STORAGE;

	$self->_db_init();
    } else {
	$self->{storage} = $STORAGE;
	$self->{namespace} = $NAMESPACE;
    }
}

# Defines structures based on the database if there is anything
# present in it.
sub _db_init {    
    my $self = shift;

    # Check for bootstrap data, bootstrap if needed.  Check for
    # consistency, create any meta tables that are missing
    $self->bootstrap();
    
    # Populate $namespace from entities from MetaEntity.
    my @entities = $self->{storage}->entities();

    for my $entity (@entities) {
	my $package = join '::', $self->{namespace}, $entity;
	$self->_register_namespace( $package );
    }
}

sub _register_namespace {
    my $self = shift;
    my $package = shift;

    print "Registering namespace '$package'...\n";
    
    eval "package $package; use base qw(Yggdrasil::Entity::Instance);";
    return $package;
}

sub _extract_entity {
  my $self = shift;

  return (split '::', ref $self)[-1];
}

sub bootstrap {
    define Yggdrasil::MetaEntity;
    define Yggdrasil::MetaRelation;
    define Yggdrasil::MetaProperty;
    define Yggdrasil::MetaInheritance;
}

sub exists {
    my $caller = shift;

    if (ref $caller) {
	warn "Calling exists with a reference from $caller...\n";
	my $entity = $caller->_extract_entity();
	return $caller->{storage}->exists( $caller, @_ );
    } else {
	$caller =~ s/^${NAMESPACE}:://;
	return $STORAGE->exists( $caller, @_ );
    }
}

sub property_exists {
    my $caller = shift;
    return Yggdrasil::Property->exists( @_ );    
}

1;

=head1 NAME

Yggdrasil - The great new Yggdrasil!

=head1 VERSION

Version 0.01

=cut

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Yggdrasil;

    my $foo = Yggdrasil->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 FUNCTIONS

=head2 function1

=cut

=head1 AUTHOR

Terje Kvernes & David Ranvig, C<< <terjekv at math.uio.no> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-yggdrasil at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Yggdrasil>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Yggdrasil


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Yggdrasil>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Yggdrasil>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Yggdrasil>

=item * Search CPAN

L<http://search.cpan.org/dist/Yggdrasil>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2008 Terje Kvernes & David Ranvig, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut
