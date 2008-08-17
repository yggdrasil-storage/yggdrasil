package Yggdrasil;

use strict;
use warnings;
use v5.006;

use Carp;
use Cwd qw(abs_path);
use File::Basename;
use File::Spec;
use Log::Log4perl qw(get_logger :levels :nowarn);

use Yggdrasil::MetaEntity;
use Yggdrasil::MetaProperty;
use Yggdrasil::MetaRelation;
use Yggdrasil::MetaInheritance;

use Yggdrasil::Storage;
use Yggdrasil::Entity;
use Yggdrasil::Relation;
use Yggdrasil::Property;

our $VERSION = '0.02';

our $STORAGE;
our $NAMESPACE;

our $YGGLOGGER; 

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

	my $project_root = $self->_project_root() || ".";

	my $logconfig = "$project_root/etc/log4perl-debug";
	if( -e $logconfig ) {
	    $params{logconfig} = $logconfig;
	    Log::Log4perl->init( $params{logconfig} );
	}

	$self->{logger} = $YGGLOGGER = get_logger();
	$self->{storage} = $STORAGE = Yggdrasil::Storage->new(@_);
	die "No storage layer initalized, aborting.\n" unless $STORAGE;
	
	$self->_db_init();
    } else {
	$self->{storage} = $STORAGE;
	$self->{namespace} = $NAMESPACE;
	$self->{logger} = get_logger( __PACKAGE__ );
    }
}


sub _project_root {
    my $self = shift;

    my $file = __PACKAGE__ . ".pm";
    $file =~ s|::|/|g;

    my $path = $INC{$file};
    return unless $path;

    $path = File::Spec->catdir( dirname($path), File::Spec->updir() );

    return abs_path($path);
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

    $self->{logger}->info( "Registering namespace '$package'..." );
    
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

sub entities {
    my $class = shift;

    return $STORAGE->entities();
}

# Generic exist method for non-instanced calls across Yggdrasil to see
# if a given instance of a given entity exists.  This requires
# $STORAGE to access the backend layer.  It is called as
# "Ygg::Host->exists( 'nommo' )", or "Ygg::Room->exists( 'B810' ) etc.
sub exists {
    my $class = shift;
    my $visual_id = shift;
    my @time = @_;

    my $entity = (split '::', $class)[-1];

    my $fetchref = $STORAGE->fetch( $entity, { return => 'id', where => { visual_id => $visual_id } },
				    { start => $time[0], stop => $time[1] } );

    return undef unless $fetchref->[0];
    return $fetchref->[0]->{id};
}

1;

=head1 NAME

Yggdrasil - Dynamic relational temporal object database

=head1 VERSION

Version 0.01

=cut

=head1 SYNOPSIS
    use Yggdrasil;

    Yggdrasil->new( namespace => 'Ygg', 
                    engine    => "...",
                    user      => "...",
                    ... );

    # Define an Entity 'Host' with two properties, 'ip' and 'os'
    my $host = define Yggdrasil::Entity 'Host';
    my $ip = define $host 'ip';
    my $os = define $host 'os';

    # Create an Instance of 'Host'
    my $laptop = Ygg::Host->new( 'My Laptop' );
    $laptop->property( $ip => '127.0.0.1' );
    $laptop->porperty( $os => 'Multics' );

    # Define an Entity 'Room'
    my $room = define Yggdrasil::Entity 'Room';

    # Create Instances of 'Room'
    my $basement = Ygg::Room->new( 'Basement' );
    my $kitchen  = Ygg::Room->new( 'Kitchen' );

    # Define a Relation between 'Host' and 'Room'
    define Yggdrasil::Relation $host, $room;

    # Relate "My Laptop" to "Basement"
    $laptop->link( $basement );

    # Relate "My Laptop" to "Kitchen"
    $laptop->unlink( $basement );
    $laptop->link( $kitchen );

    # Query which Hosts are in the kitchen
    $kitchen->fetch_related( $host );

    # Query the location of "My Laptop"
    $laptop->fetch_related( $room );


=head1 ABSTRACT

Yggdrasil aims to be a "dynamic relational temporal object database".
In essence, Yggdrasil aims to add two abstractions to the traditional
view of a relational database: implicit temporal storage and a simple
object model to represent the data stored. In addition to this
Yggdrasil allows the relations of the entities stored within to be
altered, and new entities and their relations to be added while the
system is running. The relations are described by the administrator of
the system and as soon as any relation is described to Yggdrasil, it
is added to the overall structure of the installation.


=head1 FUNCTIONS

=head2 new()

Initialize Yggdrasil. The new method takes at least two parameters,
namespace and engine. The namespace parameter tells Yggdrasil under
which namespace your entities should reside. The engine parameter
tells Yggdrasil which storage engine to use.

Depending on what engine you want to use, the arguments differ. See
L<Yggdrasil::Storage> for more information.

    Yggdrasil::new( namespace => 'MyNamespace',
                    engine    => 'mysql', 
                    user      => 'yggdrasil',
                    password  => 'secret',
                    db        => 'Yggdrasil' );

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

=item * SVN repository

svn co http://svn.math.uio.no/yggdrasil/trunk/ yggdrasil

=item * SVN Web interface

L<http://svn.math.uio.no/trunk/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 COPYRIGHT & LICENSE

Copyright 2008 Terje Kvernes & David Ranvig, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut
