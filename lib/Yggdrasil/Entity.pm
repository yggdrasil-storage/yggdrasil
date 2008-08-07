package Yggdrasil::Entity;

use strict;
use warnings;

use base qw(Yggdrasil::MetaEntity);

use Yggdrasil::Entity::Instance;

our $SCHEMA = <<SQL;
CREATE TABLE [name] (
  id        INT NOT NULL AUTO_INCREMENT,
  visual_id TEXT NOT NULL,

  PRIMARY KEY( id ),
  UNIQUE( visual_id(100) )
);
SQL
  
sub _define {
    my $self = shift;
    my $name = shift;

    unless( $name =~ /^[a-z]\w*$/i ) {
      die "You bastard! No hacking more from you!\n";
    }

    my $package = join '::', $self->{namespace}, $name;
    unless (__PACKAGE__->exists( $name )) {
	# --- Tell Storage to create SCHEMA    
	$self->{storage}->dosql_update( $SCHEMA, { name => $name } );

	# --- Add to MetaEntity;
	$self->_meta_add($name);

	# --- Create namespace
	$self->_register_namespace( $package );
	
	# --- Create property to store visual_id changes
	define $package "_$name";
    }
    
    return $package;
}

1;
