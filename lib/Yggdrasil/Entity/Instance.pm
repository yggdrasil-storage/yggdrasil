package Yggdrasil::Entity::Instance;

use base 'Yggdrasil::Meta';

use strict;
use warnings;

use Carp;

sub new {
  my $class = shift;

  my( $pkg ) = caller();
  my $self = $class->SUPER::new(@_);

  return $self if $pkg ne __PACKAGE__ && $pkg =~ /^Yggdrasil::/;

  # --- do stuff
  my $visual_id = shift;

  if( $pkg eq __PACKAGE__ ) {
    my @time = @_;

    $self->{_start} = $time[0];
    $self->{_stop}  = $time[1];
  }

  $self->{visual_id} = $visual_id;

  my $entity = $self->_extract_entity();
  $self->{_id} = $self->_get_id(); 

  unless ($self->{_id}) { 
      $self->{storage}->store( 'Entities', fields => {
						      visual_id => $visual_id,
						      entity    => $entity,
						     } );
      $self->{_id} = $self->_get_id();
  }
  
  return $self;
}

sub _get_id {
    my $self = shift;
    my $entity = $self->_extract_entity();
    my $idfetch = $self->{storage}->fetch( 'Entities', { return => "id", where => { 
										   visual_id => $self->id(),
										   entity    => $entity,
										  } } );
    return $idfetch->[0]->{id};
}

sub get {
  my $class = shift;
  my $visual_id = shift;
  my @time = @_;

  confess "When calling get with a time slice specified, you will recieve a list"
    if @time > 1 && ! wantarray;
  
  # If the user only specifies one time argument, then stop should be set equal to start,
  # meaning get is called for a specific moment in time.
  if( @time == 1 ) {
      push( @time, $time[0] );
  }
  
  my @objects;
  for my $dataref ($class->_get_in_time( $visual_id, @time )) {
      push @objects, $class->new( $visual_id, $dataref->{start}, $dataref->{stop} );
  }

  if (@time && $time[0] && $time[1] && $time[0] ne $time[1]) {
      return @objects;
  } else {
      return $objects[-1];
  }
}

sub _get_in_time {
    my $class = shift;
    my $visual_id = shift;
    my @time = @_;

    my $entity = (split '::', $class)[-1];

    # Short circuit the joins if we're looking for the current object
    unless (@time) {
	my $fetchref = $Yggdrasil::STORAGE->fetch( 'Entities' => { return => "id", where => {
											     visual_id => $visual_id,
											     entity    => $entity,
											    } } );
	my $id = $fetchref->[0]->{id};

	if ($id) {
	    return { id => $id };
	} else {
	    return;
	}
    }
    
    my $fetchref = $Yggdrasil::STORAGE->fetch( "MetaProperty" => { return => "property", where => { entity => $entity } },
					       { start => $time[0], stop => $time[1] } );

    my @wheres;
    push( @wheres, 'Entities' => { join => "left", where => { visual_id => $visual_id, entity => $entity } } );

    foreach my $prop ( map { $_->{property} } @$fetchref ) {
	my $table = join("_", $entity, $prop);

	push( @wheres, $table => { join => "left" } );
    }

    my $ref = $Yggdrasil::STORAGE->fetch( @wheres,
					  { start => $time[0], stop => $time[1] } );
    

    # ... fetch all uniq start-times, filter only starts between $time[0] and $time[1] and return
    my %times;
    if( defined $time[0] || defined $time[1] ) {
	if (defined $time[0] && defined $time[1] && $time[0] == $time[1] && @$ref) {
	    return {
		    start => $time[0],
		    stop  => $time[0]
		   };
	}

	foreach my $e ( @$ref ) {
	    foreach my $key ( keys %$e ) {
		next unless $key =~ /_start$/;
		
		my $val = $e->{$key};

#		print "VAL = $key $val $time[0] :: $time[1]\n";
		my $good;
		if( defined $time[0] ) {
		    if( defined $time[1] ) {
			$good = $time[0] <= $val && $val < $time[1];
		    } else {
			$good = $val >= $time[0] if $val && $time[0];
		    }
		} elsif( defined $time[1] ) {
		    $good = $val < $time[1];
		}
		
		if( $good ) {
#		    print "GOOD VAL = $val\n";
		    $times{$val} = { start => $val };
		}
	    }
	}

	my @sorted = map { $times{$_} } sort { $a <=> $b } keys %times;
	for( my $i = 0; $i < @sorted; $i++ ) {
	    my $e = $sorted[$i];
	    my $next = $sorted[$i+1] || {};

	    if( $i == 0 ) {
		$e->{start} = $time[0];
	    }

	    $e->{stop} = $next->{start} || $time[1];
	}

	return @sorted;
    }
    
    return @$ref;
}


sub _define {
  my $self     = shift;
  my $entity = $self->_extract_entity();

  return Yggdrasil::Property->define( $entity, @_ );
}

sub property {
    my $self = shift;
    my ($key, $value) = @_;

    my $storage = $self->{storage};

    my $entity = $self->_extract_entity();
    my $name = join("_", $entity, $key );

    die "Unable to find property '$key' for entity '$entity', exiting.\n" unless $self->property_exists( $entity, $key );
    
    # Did we get two params, even if one was undef?
    if (@_ == 2) {
	if( defined $self->{_start} || defined $self->{_stop} ) {
	    die "Temporal objects are immutable.";
	}

	$storage->store( $name, key => "id", fields => { id => $self->{_id}, value => $value } );
    }

    my $r = $storage->fetch( $name => { return => "value", where => { id => $self->{_id} } },
			   { start => $self->{_start}, stop => $self->{_stop} } );
    return $r->[0]->{value};
}

sub property_exists {
    my ($self, $entity, $property) = @_;
    my $storage = $self->{storage};
    
    # Check to see if the property exists.
    my $aref = $storage->fetch( 'MetaProperty', 
				{ return => 'property', 
				  where => { entity => $entity, property => $property } 
				} );

    # The property name might be "0".
    return defined $aref->[0]->{property}?1:0;
}

sub properties {
    my $class = shift;

    if (ref $class) {
	$class = $class->_extract_entity();
    } else {
	$class =~ s/.*:://;
    }

    my $aref = $Yggdrasil::STORAGE->fetch( 'MetaProperty', 
					   { return => 'property', 
					     where => { entity => $class } 
					   } );
    
    return map { $_->{property} } @$aref;    
}

sub relations {
    my $class = shift;

    if (ref $class) {
	$class = $class->_extract_entity();
    } else {
	$class =~ s/.*:://;
    }
    
    my $lref = $Yggdrasil::STORAGE->fetch( 'MetaRelation', 
					   { return => 'entity2', 
					     where => { entity1 => $class } 
					   } );
    my $rref = $Yggdrasil::STORAGE->fetch( 'MetaRelation', 
					   { return => 'entity1', 
					     where => { entity2 => $class } 
					   } );
    
    return map { $_->{entity1} || $_->{entity2} } @$lref, @$rref;    
}

# fetches all current instance for an Entity
sub instances {
    my $class = shift;

    if (ref $class) {
	$class = $class->_extract_entity();
    } else {
	$class =~ s/.*:://;
    }
    
    my $instances = $Yggdrasil::STORAGE->fetch( Entities => { return => 'visual_id', where => { entity => $class } } );
    
    return map { $_->{visual_id} } @$instances;
}


# Property type function for non-instanced calls.
# It is called as "Ygg::Entity->type( 'propertyname' );
sub type {
    my ($class, $property) = @_;

    if (ref $class) {
	$class = $class->_extract_entity();
    } else {
	$class =~ s/.*:://;
    }
    
    my $ret = $Yggdrasil::STORAGE->fetch( 'MetaProperty',{ return => 'type',
					    where  => { entity   => $class,
					               property => $property }});
    return map { $_->{type} } @$ret;
}


sub search {
    my ($class, $key, $value) = @_;
    my $package = $class;
    $class =~ s/.*:://;
    
    my $nodes = $Yggdrasil::STORAGE->search( $class, $key, $value );

    return map { my $new = $package->SUPER::new(); $new->{visual_id} = $_;
		 $new->{_id} = $nodes->{$_}; $new } keys %$nodes;
}

sub link :method {
  my $self     = shift;
  my $instance = shift;

  my $e1 = $self->_extract_entity();
  my $e2 = $instance->_extract_entity();

  my $schema = $self->{storage}->_get_relation( $e1, $e2 );
  
  # Check to see if the relationship between the entities is defined
  confess "Undefined relation between $e1 / $e2 requested." unless $schema;

  my $e1_side = $self->_relation_side( $schema, $e1 );
  my $e2_side = $self->_relation_side( $schema, $e2 );

  $self->{storage}->store( $schema,
			   key => 'id',
			   fields => { $e1_side => $self->{_id},
				       $e2_side => $instance->{_id} });
}

sub unlink :method {
  my $self     = shift;
  my $instance = shift;
 
  my $e1 = $self->_extract_entity();
  my $e2 = $instance->_extract_entity();
  
  my $storage = $self->{storage};

  my $schema = $storage->_get_relation( $e1, $e2 );

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

  my $relations = $self->{storage}->fetch( 'MetaRelation', {} );
  my @relations = map { [$_->{entity1}, $_->{entity2}, $_->{relation} ] } @$relations;


  my %table_map;
  foreach my $r ( @relations ) {
    my( $e1, $e2, $rel ) = @$r;
    $table_map{ join("_", $e1, $e2) } = [ $rel, $e1 ];
    $table_map{ join("_", $e2, $e1) } = [ $rel, $e1 ];
  }

  my %result;
  for my $path ( @$paths ) {
#    print "ZOOM ",  join( " -> ", @$path), "\n";
  
    my @tmp_path = @$path;
    my $node = shift @tmp_path;
    my @ordered;
    foreach my $step ( @tmp_path ) {
       push( @ordered, $table_map{ join("_", $node, $step) }->[0] );
       $node = $step;
     }


    my @schema;
    my $first = $ordered[0];
    my $side = $self->_relation_side( $first, $source );
    my $firsttable = $self->_map_schema_name( $first );
    push( @schema, $firsttable => { where => { $side => $self->{_id} } } );

    my $prev = $first;
    for( my $i=1; $i<@ordered; $i++ ) {
      my $table = $ordered[$i];

      my $rel = $table_map{ join("_", $table, $prev) };
      
      my $current = $self->_relation_side( $table, $path->[$i] );
      my $next    = $self->_relation_side( $prev, $path->[$i] );
      my $tabname = $self->_map_schema_name( $table );
      my $prevtab = $self->_map_schema_name( $prev );
      
      push( @schema, $tabname => { where => { $current => \qq<$prevtab.$next> } } );
      $prev = $table;
    }
    
    $side = $self->_relation_side( $ordered[-1], $path->[-1] );
    my ($ordtab, $pathtab) = ($self->_map_schema_name( $ordered[-1] ), $self->_map_schema_name( $path->[-1] ));
    push(@schema, Entities => { return => "visual_id", 
				where => { id     => \qq<$ordtab.$side>,
					   entity => $path->[-1] } } );

    my $pathtable  = $self->_map_schema_name( $path->[-1] );

    my $res = $self->{storage}->fetch( @schema );
    
    foreach my $r ( @$res ) {
      $self->{logger}->error( $r->{visual_id} );
      my $name = "$self->{namespace}::$relative";
      my $obj = $name->new( $r->{visual_id} );
      $obj->{_pathlength} = scalar @$path - 1;
      
      $result{$r->{visual_id}} = $obj;
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

  # FIX: we need to implement "OR"-operator or "SET"-operator. Doing
  # to fecthes to simulate "OR" sucks.
  my $rs = $storage->fetch( 'MetaRelation',
			    { return => "entity2", 
			      where => { entity1 => $start } } );
  my $ls = $storage->fetch( 'MetaRelation',
			    { return => "entity1",
			      where => { entity2 => $start } } );

  my @siblings = map { $_->{entity1} || $_->{entity2} } @$rs, @$ls;
  foreach my $child ( @siblings ) {
    my $found_path = $self->_fetch_related( $child, $stop, $path, $all );

    push( @$all, $found_path ) if $found_path;
  }

  return $all if @$path == 1;
}

sub _map_schema_name {
    my $self = shift;
    
    return $self->{storage}->_map_schema_name( @_ );
#Yggdrasil::Storage::SQL::
}

1;
