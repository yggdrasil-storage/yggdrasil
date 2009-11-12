package Yggdrasil;

use strict;
use warnings;
use v5.006;

use Cwd qw(abs_path);
use File::Basename;
use File::Spec;
use Log::Log4perl qw(get_logger :levels :nowarn);
use Carp;

use Yggdrasil::MetaAuth;
use Yggdrasil::Auth;

use Yggdrasil::MetaEntity;
use Yggdrasil::MetaProperty;
use Yggdrasil::MetaRelation;
use Yggdrasil::MetaInheritance;

use Yggdrasil::Storage;
use Yggdrasil::Entity;
use Yggdrasil::Relation;
use Yggdrasil::Property;
use Yggdrasil::User;
use Yggdrasil::Role;

use Yggdrasil::Status;
use Yggdrasil::Debug;

our $VERSION = '0.10';

sub yggdrasil {
    my $self = shift;

    return $self;
}

sub version {
    return $VERSION;
}

sub new {
    my $class = shift;
    my $self  = bless {}, $class;
    my %params = @_;

    if ( ref $self eq __PACKAGE__ ) {
	$self->{status} = new Yggdrasil::Status();
	$self->_setup_logger( $params{logconfig} );
	$self->{auth}   = new Yggdrasil::Auth( yggdrasil => $self );
	Yggdrasil::Debug->new( $params{debug} );
	$self->{strict} = $params{strict} || 1;
	$self->{status}->set( 200 );
    } else {
	Yggdrasil::fatal( "in new() in Yggdrasil! should not be here!" );
#	Yggdrasil::fatal( "Did not get an yggdrasil reference passed upon creation of '$class'") unless $params{yggdrasil};
#	$self->{name}      = $params{name};
#	$self->{yggdrasil} = $params{yggdrasil};
#	$self->{logger} = get_logger( __PACKAGE__ );
    }
    
    return $self;
}

sub get_status {
    my $self = shift;
    return $self->{status};
}


sub bootstrap {
    my $self = shift;
    my %userlist = @_;
    
    my $status = $self->get_status();
    if ($self->{storage}->yggdrasil_is_empty()) {
	$self->{bootstrap} = 1;
	Yggdrasil::MetaEntity->define( yggdrasil => $self );
	Yggdrasil::MetaRelation->define( yggdrasil => $self );
	Yggdrasil::MetaProperty->define( yggdrasil => $self );
	Yggdrasil::MetaInheritance->define( yggdrasil => $self );
	
	Yggdrasil::MetaAuth->define( yggdrasil => $self );

	my $universal = $self->define_entity( 'UNIVERSAL' );
	
	# FIX: add default users to %userlist _here_, before calling this and rename that horrible function name!
	my @users = Yggdrasil::Auth->_setup_default_users_and_roles( yggdrasil => $self, users => \%userlist );
	my %usermap;
	
	for my $user (@users) {
	    $usermap{$user->id()} = $user->password();
	}
	$status->set( 200, 'Bootstrap successful.');
	return \%usermap;
    } else {
	$status->set( 406, "Unable to bootstrap, data exists." );
	return;
    }
}

sub connect {
    my $self = shift;

    $self->{storage} = Yggdrasil::Storage->new(@_,
					       status => $self->{status},
					       auth   => $self->{auth},
	);

    return unless $self->get_status()->OK();

    return 1;
}

sub login {
    my $self = shift;
    my %params = @_;

    my $status = $self->get_status();

    if( $self->user() ) {
	$status->set( 406, 'Already logged in' );
	return;
    }

    my $auth = new Yggdrasil::Auth( yggdrasil => $self );
    $self->{user} = $auth->authenticate( %params );

    if ($status->OK()) {
	$self->{storage}->{user} = $self->user();
	return $self->user();
    }

    return;
}

sub user {
    my $self = shift;
    return $self->{user};
}

###############################################################################
# Defines
sub define_user {
    my $self = shift;
    my $user = shift;

    return Yggdrasil::User->define( yggdrasil => $self, user => $user, @_ );
}

sub define_role {
    my $self = shift;
    my $role = shift;

    return Yggdrasil::Role->define( yggdrasil => $self, role => $role, @_ );
}

sub define_entity {
    my $self   = shift;
    my $entity = shift;

    return Yggdrasil::Entity->define( yggdrasil => $self, entity => $entity, @_ );
}

sub define_relation {
    my $self = shift;
    my $e1 = shift;
    my $e2 = shift;

    return Yggdrasil::Relation->define( yggdrasil => $self, entities => [$e1, $e2], @_ );
}

sub define_property {
    my $self = shift;
    my $prop = shift;
    
    return Yggdrasil::Property->define( yggdrasil => $self, property => $prop, @_ );
}

###############################################################################
# Get
sub get_user {
    my $self = shift;
    my $user = shift;

    return Yggdrasil::User->get( yggdrasil => $self, user => $user, @_ );
}

sub get_role {
    my $self = shift;
    my $role = shift;

    return Yggdrasil::Role->get( yggdrasil => $self, role => $role, @_ );
}

sub get_entity {
    my $self   = shift;
    my $entity = shift;

    return Yggdrasil::Entity->get( yggdrasil => $self, entity => $entity, @_ );
}

sub get_relation {
    my $self = shift;
    my $label = shift;

    return Yggdrasil::Relation->get( yggdrasil => $self, label => $label, @_ );
}

sub get_property {
    my $self = shift;
    my $prop = shift;
    
    return Yggdrasil::Property->get( yggdrasil => $self, property => $prop, @_ );
}

###############################################################################
# Undefines
sub undefine_user {
    my $self = shift;
    my $user = shift;

    return Yggdrasil::User->undefine( yggdrasil => $self, user => $user, @_ );
}

sub undefine_role {
    my $self = shift;
    my $role = shift;

    return Yggdrasil::Role->undefine( yggdrasil => $self, role => $role, @_ );
}

sub undefine_entity {
    my $self   = shift;
    my $entity = shift;

    return Yggdrasil::Entity->undefine( yggdrasil => $self, entity => $entity, @_ );
}

sub undefine_relation {
    my $self  = shift;
    my $label = shift;

    return Yggdrasil::Relation->undefine( yggdrasil => $self, label => $label, @_ );
}

sub undefine_property {
    my $self = shift;
    my $prop = shift;

    return Yggdrasil::Property->undefine( yggdrasil => $self, property => $prop,  @_ );
}


###############################################################################
# other public methods

# entities, returns all the entities known to Yggdrasil.
sub entities {
    my $self = shift;

    my @roles = $self->user()->member_of();
    my @roleids = map { $_->{_role_obj}->{_id} } @roles;

    my $aref = $self->{storage}->_fetch( 
	MetaAuthEntity => { where => [ role => \@roleids, readable => 1 ]},
	MetaEntity     => { where => [ id => \qq{MetaAuthEntity.entity}, ],
			    return => 'entity' });

    return map { Yggdrasil::Entity::objectify( name      => $_->{entity}, 
					       yggdrasil => $self ) } @$aref;
}


# relations, returns all the relations known to Yggdrasil.
sub relations {
    my $self = shift;
    my $aref = $self->{storage}->fetch( 'MetaRelation', { return => [ 'rval', 'lval', 'label' ] });

    return map { $_->{label} } @$aref;
}

# Generic exist method for non-instanced calls across Yggdrasil to see
# if a given instance of a given entity exists.  It is called as
# "$HOSTOBJ->exists( 'nommo' )", or "$ROOMOBJ->exists( 'B810' ) etc.
sub exists {
    my $self = shift;
    my $visual_id = shift;
    my @time = @_;

    my $entity = $self->_extract_entity(ref $self);

    my $fetchref = $self->{storage}->fetch( 'Entities', { return => 'id',
							  where  => [ visual_id => $visual_id,
								      entity    => $entity ] },
					    { start => $time[0], stop => $time[1] } );
    
    return undef unless $fetchref->[0];
    return $fetchref->[0]->{id};
}


###############################################################################
# Helper functions
sub _setup_logger {
    my $self = shift;
    
    my $project_root = $self->_project_root() || ".";
    my $logconfig = shift || "$project_root/etc/log4perl-debug";
    
    if( -e $logconfig ) {
	Log::Log4perl->init( $logconfig );
    } else {
	# warn( "No working Log4perl configuration found in $logconfig." );
    }

    $self->{logger} = get_logger();
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


# Exit method if something really breaks.  It should be used over
# "die" or "confess" throughout Yggdrasil to provide a default exit
# due to critical errors.  It is intended to be terse, user "readable"
# yet provide some debugging information for developers.
sub fatal {
    my @texts = @_;
    
    my $text = join("\n", @texts);
    my ($package, $filename, $line) = caller();
    my ($subroutine) = (caller(1))[3];
    print STDERR "Yggdrasil encountered a fatal error, in $subroutine (line $line):\n";
    confess( "$text" );
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
