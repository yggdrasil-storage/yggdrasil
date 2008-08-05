package Yggdrasil::Entity::Instance;

use base 'Yggdrasil::Meta';

use strict;
use warnings;

our $SCHEMA = <<SQL;
CREATE TABLE [name] (
  id     INT NOT NULL,
  value  TEXT NULL,
  start  DATETIME NOT NULL,
  stop   DATETIME NULL,

  PRIMARY KEY( id, value(50), start ),
  FOREIGN KEY( id ) REFERENCES [entity]( id ),
  CHECK( start < stop )
);
SQL

sub new {
  my $class = shift;

  my( $pkg ) = caller();
  my $self = $class->SUPER::new(@_);

  return $self if $pkg ne 'Yggdrasil::Entity::Instance' && $pkg =~ /^Yggdrasil::/;

  # --- do stuff
  my $visual_id = shift;
  $self->{visual_id} = $visual_id;

  my $entity = $self->_extract_entity();
  $self->{_id} = $self->{storage}->fetch( $entity, visual_id => $visual_id );

  unless ($self->{_id}) { 
    $self->{_id} = $self->{storage}->update( $entity, visual_id => $visual_id );
    $self->property( "_$entity" => $visual_id );
  }

  return $self;
}

sub get {
  my $class = shift;
  my $visual_id = shift;

  print "--------> HERE <----------\n";

  if ($class->exists( $visual_id)) {
      return $class->new( $visual_id );
  } else {
      return undef;
  }

}

sub _define {
  my $self     = shift;
  my $property = shift;

  my( $pkg ) = caller(0);
  if( $property =~ /^_/ && $pkg !~ /^Yggdrasil::/ ) {
    die "You bastard! private properties are not for you!\n";
  }
  my $entity = $self->_extract_entity();
  my $name = join("_", $entity, $property);

  unless ($self->property_exists( $entity, $property )) { 
      # --- Create Property table
      $self->{storage}->dosql_update( $SCHEMA, { name => $name, entity => $entity } );
      
      # --- Add to MetaProperty
      $self->{storage}->update( "MetaProperty", entity => $entity, property => $property );
  }  

  return $property;
}

sub property {
    my $self = shift;
    my ($key, $value) = @_;

    my $storage = $self->{storage};

    my $entity = $self->_extract_entity();
    my $name = join("_", $entity, $key );
      
    if ($value) {
      $storage->update( $name, id => $self->{_id}, value => $value );
    }

    return $storage->fetch( $name, id => $self->{_id} );
}

sub properties {
    my $self = shift;
    my $class = ref $self;
    $class =~ s/.*:://;
    
    return $self->{storage}->properties( $class );
}

sub link :method {
  my $self     = shift;
  my $instance = shift;

  my $e1 = $self->_extract_entity();
  my $e2 = $instance->_extract_entity();

  my $storage = $self->{storage};

  my $schema = $storage->fetch( "MetaRelation", entity1 => $e1, entity2 => $e2 );
  print "-----------> [$schema]\n";

  my $e1_side = $self->_relation_side( $schema, $e1 );
  my $e2_side = $self->_relation_side( $schema, $e2 );


  # Check to see if the relationship between the entities is defined
  if ($schema) {
      $storage->update( $schema, 
			$e1_side => $self->{_id},
			$e2_side => $instance->{_id} );
  }
}

sub unlink :method {
  my $self     = shift;
  my $instance = shift;
 
  my $e1 = $self->_extract_entity();
  my $e2 = $instance->_extract_entity();
  
  my $storage = $self->{storage};

  my $schema = $storage->fetch( "MetaRelation", entity1 => $e1, entity2 => $e2 );
  print "-----------> [$schema]\n";

  my $e1_side = $self->_relation_side( $schema, $e1 );
  my $e2_side = $self->_relation_side( $schema, $e2 );
  

  $storage->expire( $schema, $e1_side => $self->{_id}, $e2_side => $instance->{_id} );
}

sub id {
  my $self = shift;
  
  return $self->{visual_id};
}

sub pathlength {
    my $self = shift;
    return $self->{_pathlength};
}

sub fetch_related {
  my $self = shift;
  my $relative = shift;

  $relative =~ s/^.*:://;
  my $source = $self->_extract_entity();

  my $paths = $self->_fetch_related( $source, $relative );
  



  my @relations = $self->{storage}->relations();
  my %table_map;
  foreach my $r ( @relations ) {
    my( $e1, $e2, $rel ) = @$r;
    $table_map{ join("_", $e1, $e2) } = [ $rel, $e1 ];
    $table_map{ join("_", $e2, $e1) } = [ $rel, $e1 ];
  }

  my %result;
  for my $path ( @$paths ) {
    print "ZOOM ",  join( " -> ", @$path), "\n";
  
    my @tmp_path = @$path;
    my $node = shift @tmp_path;
    my @ordered;
    foreach my $step ( @tmp_path ) {
       push( @ordered, $table_map{ join("_", $node, $step) }->[0] );
       $node = $step;
     }

    my $from = join(", ", @ordered,$path->[-1]);

    my @where;
    my $first = $ordered[0];
    my $side = $self->_relation_side( $first, $source );
    push( @where, "$first.$side = $self->{_id} and $first.stop is null" );
    my $prev = $first;
    for( my $i=1; $i<@ordered; $i++ ) {
      my $table = $ordered[$i];

      my $rel = $table_map{ join("_", $table, $prev) };
      
      my $current = $self->_relation_side( $table, $path->[$i] );
      my $next    = $self->_relation_side( $prev, $path->[$i] );
						     
      push( @where, "$table.$current = $prev.$next and $table.stop is null");
      $prev = $table;
    }
    
    $side = $self->_relation_side( $ordered[-1], $path->[-1] );
    push(@where, "$ordered[-1].$side = $path->[-1].id" );

    my $sql = "SELECT $path->[-1].visual_id FROM $from WHERE ". join(" and ", @where);
    print "ZOOM * * *  $sql\n";
    my $res = $self->{storage}->dosql_select( $sql, [] );
    
    foreach my $r ( @$res ) {
      my $name = "$self->{namespace}::$relative";
      my $obj = $name->new( $r->{visual_id} );
      $obj->{_pathlength} = scalar @$path - 1;
      
      $result{$r->{visual_id}} = $obj;

      print "ZOOM ---> [ID] = [$obj->{_id}]\n";
    }
  }

  return sort { $a->{_pathlength} <=> $b->{_pathlength} } values %result;
}

sub _relation_side {
  my $self = shift;
  my $table = shift;
  my $entity = shift;

  my( $e1, $e2 ) = split /_R_/, $table;

#  print "ZOOM --> is $entity first in $table?\n";

  if ($e1 eq $entity) {
#    print "ZOOM --> Yes\n";
    return 'lval';
  } else {
#    print "ZOOM --> No\n";

    return 'rval';
  }
}


sub _fetch_related {
  my $self = shift;
  my $start = shift;
  my $stop = shift;
  my $path = [ @{ shift || [] } ];
  my $all = shift || [];

  my $storage = $self->{storage};

  return if grep { $_ eq $start } @$path;
  push( @$path, $start );

  return $path if $start eq $stop;

  foreach my $child ( $storage->get_relations($start) ) {
    my $found_path = $self->_fetch_related( $child, $stop, $path, $all );

    push( @$all, $found_path ) if $found_path;
  }

  return $all if @$path == 1;
}

1;
