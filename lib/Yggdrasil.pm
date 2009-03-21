package Yggdrasil;

use strict;
use warnings;
use v5.006;

use Cwd qw(abs_path);
use File::Basename;
use File::Spec;
use Log::Log4perl qw(get_logger :levels :nowarn);
use Carp;

use Yggdrasil::MetaEntity;
use Yggdrasil::MetaProperty;
use Yggdrasil::MetaRelation;
use Yggdrasil::MetaInheritance;
use Yggdrasil::MetaAuth;

use Yggdrasil::Auth;
use Yggdrasil::Storage;
use Yggdrasil::Entity;
use Yggdrasil::Relation;
use Yggdrasil::Property;

use Yggdrasil::Status;
use Yggdrasil::Debug;

our $VERSION = '0.10';

sub new {
    my $class = shift;
    my $self  = bless {}, $class;
    my %params = @_;

    if ( ref $self eq __PACKAGE__ ) {
	$self->_setup_logger( $params{logconfig} );
	$self->{status} = new Yggdrasil::Status();
	$self->{auth}   = new Yggdrasil::Auth( yggdrasil => $self );
	$self->{status}->set( 200 );
	Yggdrasil::Debug->new( $params{debug} );
	$self->{strict} = $params{strict} || 1;
    } else {
	Yggdrasil::fatal( "Did not get an yggdrasil reference passed upon creation of '$class'") unless $params{yggdrasil};
	$self->{name}      = $params{name};
	$self->{yggdrasil} = $params{yggdrasil};
	$self->{logger} = get_logger( __PACKAGE__ );
    }
    
    return $self;
}

sub get_status {
    my $self = shift;
    return $self->{status};
}
  
sub connect {
    my $self = shift;

    return $self->{storage} = Yggdrasil::Storage->new(@_,
						      status => $self->{status},
						      auth   => $self->{auth},
						     );
    
}

sub login {
    my $self = shift;
    my %params = @_;

    my $auth = define Yggdrasil::Auth( yggdrasil => $self );
    $auth->authenticate( user => $params{user}, pass => $params{password} );

    my $status = $self->get_status();
    if ($status->OK()) {
	$self->{storage}->{user} = $self->{user} = $auth->{user};
    }
}

# Interface to get / define users.
sub define_user {
    my $self = shift;
    
    my $ygg  = $self->{yggdrasil} || $self;
    my $ao = new Yggdrasil::Auth( yggdrasil => $ygg );
    
    return $ao->_define_user( @_ );
}

# This is awefully ugly.  FIXME.
sub get_role_from_active_user {
    my $self = shift;
    
    my $idref = $self->{storage}->_fetch(MetaAuthRolemembership => { where => [ user => \qq{Entities.id} ],
								     return => 'role' },
					 Entities => { where => [ visual_id => $self->{user} ]});

    my $roref = $self->{storage}->_fetch(Entities => { where => [ id => $idref->[0]->{role} ],
						       return => 'visual_id' });

    my $meta_role = $self->get_entity( 'MetaAuthRole' );
    my $ro = $meta_role->fetch( $roref->[0]->{visual_id} );
    my $role = bless $ro, 'Yggdrasil::Auth::Role';
    $role->{name} = 'MetaAuthRole';
    return $role;
}

# Interface to get / define roles.
sub define_role {
    my $self = shift;
    
    my $ygg  = $self->{yggdrasil} || $self;
    my $ao = new Yggdrasil::Auth( yggdrasil => $ygg );
    
    return $ao->_define_role( @_ );
}

# Interface to get / define entities.
sub define_entity {
    my $self = shift;

    my $entity = shift;
    my $ygg    = $self->{yggdrasil} || $self;

    return Yggdrasil::Entity->define( name => $entity, yggdrasil => $ygg );
}

sub get_entity {
    my $self = shift;
    my $entity = shift;
    
    my $aref = $self->{storage}->fetch( 'MetaEntity', { where => [ entity => $entity ],
							return => 'entity' } );
    
    my $status = $self->get_status();
    unless (defined $aref->[0]->{entity}) {
	$status->set( 404, "Entity '$entity' not found." );
	return undef;
    } 
    
    $status->set( 200 );
    $entity = new Yggdrasil::Entity( name => $entity, yggdrasil => $self );
    return $entity;
}

sub define_relation {
    my $self = shift;
    my ($e1, $e2, $label) = @_;
    
    return Yggdrasil::Relation->define( entities  => [ $e1, $e2 ], label => $label,
					yggdrasil => $self->{yggdrasil} || $self );
}

sub get_relation {
    my $self = shift;
    my $label = shift;
    
    return Yggdrasil::Relation->fetch( label => $label, yggdrasil => $self->{yggdrasil} || $self );
}

sub define_property {
    my $self = shift; # Entity.
    my $name = shift; # Name of property;
    my %param = @_; # Options hash.
    
    my $property = Yggdrasil::Property->define( $self, $name, @_, yggdrasil => $self->{yggdrasil} || $self);
    return $property;
}

sub _setup_logger {
    my $self = shift;
    
    my $project_root = $self->_project_root() || ".";
    my $logconfig = shift || "$project_root/etc/log4perl-debug";
    
    if( -e $logconfig ) {
	Log::Log4perl->init( $logconfig );
	$self->{logger} = get_logger();
    } else {
	warn( 'No working Log4perl configuration found.' );
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

sub _extract_entity {
  my $self = shift;
  return $self->{name};
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
	
	my @users = Yggdrasil::Auth->_setup_default_users_and_roles( yggdrasil => $self, users => \%userlist );
	my %usermap;
	
	for my $user (@users) {
	    $usermap{$user->id()} = $user->property( 'password' );
	}
	$status->set( 200, 'Bootstrap successful.');
	return \%usermap;
    } else {
	$status->set( 406, "Unable to bootstrap, data exists." );
	return;
    }
}

# entities, returns all the entities known to Yggdrasil.
sub entities {
    my $self = shift;
    my $aref = $self->{storage}->fetch( 'MetaEntity', { return => 'entity' } );
    
    return map { $_->{entity} } @$aref;
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
