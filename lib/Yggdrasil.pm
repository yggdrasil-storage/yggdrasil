package Yggdrasil;

use strict;
use warnings;
use v5.006;

use Cwd qw(abs_path);
use File::Basename;
use File::Spec;
use Time::Local;
use Log::Log4perl qw(get_logger :levels :nowarn);
use Carp;

use Storage;
use Storage::Status;

use Yggdrasil::MetaEntity;
use Yggdrasil::MetaProperty;
use Yggdrasil::MetaRelation;

use Yggdrasil::Entity;
use Yggdrasil::Relation;
use Yggdrasil::Property;
use Yggdrasil::User;
use Yggdrasil::Role;

use Yggdrasil::Debug;

use Yggdrasil::Interface::Client;

our $VERSION = '0.11';

# $SIG{__DIE__} = sub {
#     $Carp::CarpLevel = 1;
#     print "\nERROR: $_[0]\n\n";
#     print "TRACEBACK:\n";
#     confess();
# };

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
	$self->{status} = new Storage::Status();
	$self->_setup_logger( $params{logconfig} );
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
	my %usermap = $self->{storage}->bootstrap( %userlist );
	Yggdrasil::MetaEntity->define( yggdrasil => $self );
	Yggdrasil::MetaRelation->define( yggdrasil => $self );
	Yggdrasil::MetaProperty->define( yggdrasil => $self );

	# MetaEntity was created without 'create' auth rules in order
	# for UNIVERSAL to be created. We then proceed to add 'create'
	# auth rules for MetaEntity now that we have a root entity
	my $universal = $self->define_entity( 'UNIVERSAL' );
	Yggdrasil::MetaEntity->define_create_auth( yggdrasil => $self );

	$self->get_user( 'bootstrap' )->expire();
	$status->set( 200, 'Bootstrap successful.');
	return \%usermap;
    } else {
	$status->set( 406, "Unable to bootstrap, data exists." );
	return;
    }
}

sub connect {
    my $self = shift;
    my %params = @_;

    # Check to see if we're connecting to a remote Yggdrasil server.
    # If so, avoid calling Storage in any way.
    if ($params{daemonport}) {
	$self->{client} = new Yggdrasil::Interface::Client( status => $self->{status} );
	$self->{client}->connect( @_ );
    } else {
	$self->{storage} =
	  Storage->new(@_, status => $self->{status} );
    }

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

    if ($self->{client}) {
	# FIXME, create user objects properly.
	$self->{client}->login( %params );	
    } else {
	# we're nobody until authenticated
	$self->{user} = $self->get_user( $self->{storage}->user() );
	
	my $auth = $self->{storage}->authenticate( %params );
	$self->{user} = $self->get_user( $auth );
	
	return $self->user() if $status->OK();
	
	$status->set( 403, 'Login to Yggdrasil denied.' );
    }

    return;
}

sub user {
    my $self = shift;
    return $self->{user};
}

sub info {
    my $self = shift;
    my $storage = $self->{storage};

    return $storage->info();
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

    return Yggdrasil::User->get( yggdrasil => $self, user => $user );
}

sub get_role {
    my $self = shift;
    my $role = shift;

    return Yggdrasil::Role->get( yggdrasil => $self, role => $role );
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

sub get_property_types {
    my $self = shift;
    return $self->{storage}->get_defined_types();
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

    my $aref = $self->{storage}->fetch( MetaEntity => { return => 'entity' });

    return map { Yggdrasil::Entity::objectify( name      => $_->{entity}, 
					       yggdrasil => $self ) } @$aref;
}

# relations, returns all the relations known to Yggdrasil.
sub relations {
    my $self = shift;
    my $aref = $self->{storage}->fetch( 'MetaRelation', { return => [ 'rval', 'lval', 'label' ] });

    return map { $_->{label} } @$aref;
}


# users, returns all users known to Yggdrasil. 
sub users {
    my $self = shift;
    
    return Yggdrasil::User->get_all( yggdrasil => $self );
}


# roles, returns all roles known to Yggdrasil.
sub roles {
    my $self = shift;
    
    return Yggdrasil::Role->get_all( yggdrasil => $self, @_ );
}

# Generic exist method for non-instanced calls across Yggdrasil to see
# if a given instance of a given entity exists.  It is called as
# "$HOSTOBJ->exists( 'nommo' )", or "$ROOMOBJ->exists( 'B810' ) etc.
sub exists {
    my $self = shift;
    my $visual_id = shift;
    my @time = @_;

    my $entity = $self->_extract_entity(ref $self);

    my $fetchref = $self->{storage}->fetch( 'Instances', { return => 'id',
							  where  => [ visual_id => $visual_id,
								      entity    => $entity ] },
					    { start => $time[0], stop => $time[1] } );
    
    return undef unless $fetchref->[0];
    return $fetchref->[0]->{id};
}

# usernames / rolenames, returns all the usernames / rolenames known
# to Yggdrasil.
sub usernames {
    my $self = shift;
    return map { $_->username() } Yggdrasil::User->get_all( yggdrasil => $self );
}

sub rolenames {
    my $self = shift;
    return map { $_->rolename() } Yggdrasil::Role->get_all( yggdrasil => $self );
}

# to access defined storage types
sub property_types {
    my $self = shift;

    return $self->{storage}->get_defined_types();
}

# How to enter time formats... Best suggestions so far are:
#  * epoch (duh)
#  * YYYY-MM-DD HH:MM:SS
#
# The full format can also be intepreted from right to left with
# increasing detail, so you could enter "04:22" and get 22 seconds
# past 04 in the morning, with todays date information added by
# default.  Just typing 22 means on the 22nd second of the current
# minute, which is an interesting request.  If you'd want to give a
# time slice of five minutes after 5pm, you'd have to enter 17:00:00
# and 17:05:00 (although 0 and 00 would be equally valid). This might
# be a bit cumbersome but at least it's well-defined.

sub get_ticks_by_time {
    my $self = shift;
    my $from = $self->_get_epoch_from_input( shift );
    my $to   = $self->_get_epoch_from_input( shift );

    return unless defined $from;

    # We need to feed the backend something it can use, and they like
    # working with all sorts of weird stuff, but we'll delegate that
    # to the storage layer.
    
    return $self->{storage}->get_ticks_from_time( $from, $to );
}

# We're only doing resolution down to a second, so we can use epoch
# internally, which is oddly enough what _get_epoch_from_input as
# given us.  This'll need fixing by 2038...
sub _get_epoch_from_input {
    my $self = shift;
    my $time = shift;
    return unless defined $time;

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    if ($time =~ /^\d{2}$/) {
	$sec = $time;
    } elsif ($time =~ /^(\d+):(\d+)$/) {
	($min, $sec) = ($1, $2);
    } elsif ($time =~ /^(\d+):(\d+):(\d+)$/) {
	($hour, $min, $sec) = ($1, $2, $3);	
    } elsif ($time =~ /^(\d+)-(\d+)-(\d+) (\d+):(\d+):(\d+)$/) {
	($year, $mon, $mday, $hour, $min, $sec) = ($1, $2 - 1, $3, $4, $5, $6);
    } elsif ($time =~ /^(\d{3,})$/ || $time == 0) {
	# We haz epoch?  Yarp.
	return $time;
    } else {
	return;
    }
    
    return timelocal( $sec, $min, $hour, $mday, $mon, $year );
}

# Get information about the ticks in question.
sub get_ticks {
    my $self  = shift;
    my @ticks;
    
    for my $t (@_) {
	push @ticks, 'id' => $t;
    }
    
    # FIXME, return the 'stamp' field in an ISO date format.
    my $fetchref = $self->{storage}->fetch( 'Storage_ticker', { return => [ 'id', 'stamp', 'committer' ],
								where  => [ @ticks ],
								bind   => 'or',
							      } );
    
    if (! $fetchref->[0]->{stamp}) {
	$self->{status}->set( 400, 'Tick not found' );
	return undef;
    }

    my $events = $self->_get_instance_event_at_ticks( @_ );

    for my $t (@$fetchref) {
	$t->{events} = $events->{ $t->{id} };
    }
    return @$fetchref;
}

# Get all the instances that were created or expired on the given
# ticks.  Beware, asking for temporal stuff with times set will
# clobber start and stop between the tables, use 'as' or proceed with
# caution.  Oh, and we're using q<> constructs to insert the value
# literally, since a lot of db systems don't evaluate functions if
# they're added via ?.
sub _get_instance_event_at_ticks {
    my $self  = shift;
    my @ticks = @_;
    my %tick;

    my @where;
    for my $t (@_) {
	push @where, 'start' => $t, 'stop' => $t;
    }
    
    my $fetchref = $self->{storage}->fetch( 'Instances', { return => [ 'visual_id', 'start', 'stop' ],
							  where  => [ @where ],
							  bind   => 'or',
							  as     => 1,
							},
					    'MetaEntity', { return => [ 'entity' ],
							    where  => [ 'id' => \qq{Instances.entity} ],
							    as     => 1,
							  },
					    { start => 0, stop => undef },
					  );
    for my $h (@$fetchref) {
	my $etext = 'Created';
	my $id = $h->{Instances_start} || $h->{Instances_stop};
	$etext = 'Expired' if $h->{Instances_stop};
	push @{$tick{$id}}, { start => $h->{Instances_start}, stop => $h->{Instances_stop},
			      string => "$etext the instance '" . $h->{visual_id} . "' in '" . $h->{entity} . "'",
			    };
    }
    return \%tick;
}

# Transaction interface.
sub transaction_stack_get {
    my $self = shift;
    return $self->{storage}->{transaction}->get_stack();
}

sub transaction_stack_clear {
    my $self = shift;
    return $self->{storage}->{transaction}->clear_stack();
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
L<Storage> for more information.

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
