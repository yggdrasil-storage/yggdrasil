package Yggdrasil;

use strict;
use warnings;

use Carp;

use Yggdrasil::MetaEntity;
use Yggdrasil::MetaProperty;
use Yggdrasil::MetaRelation;
use Yggdrasil::MetaInheritance;

use Yggdrasil::Storage;
use Yggdrasil::Entity;
use Yggdrasil::Relation;

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
    my @missing = $self->{storage}->bootstrap_missing();
    $self->bootstrap( @missing ) if @missing;
    
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


sub bootstrap {
    my $self = shift;
    my @structures = @_;

    if ($self && @structures) {
	for my $structure (@structures) {
	    eval "define Yggdrasil::$structure";
	}
    } else {
	define Yggdrasil::MetaEntity;
	define Yggdrasil::MetaRelation;
	define Yggdrasil::MetaProperty;
	define Yggdrasil::MetaInheritance;
    }
}

sub _extract_entity {
  my $self = shift;

  return (split '::', ref $self)[-1];
}

1;
