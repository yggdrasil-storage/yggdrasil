package Yggdrasil::Entity::Instance;

use base 'Yggdrasil::Meta';

use strict;
use warnings;

sub new {
  my $class = shift;

  my( $pkg ) = caller();
  my $self = $class->SUPER::new(@_);

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
      my $idref = $self->{storage}->fetch('MetaEntity', { return => 'id',
							  where => [ entity => $entity ],
							});
      $self->{storage}->store( 'Entities', fields => {
						      visual_id => $visual_id,
						      entity    => $idref->[0]->{id},
						     } );
      $self->{_id} = $self->_get_id();
  }
  
  return $self;
}

sub _get_id {
    my $self = shift;
    my $entity = $self->_extract_entity();

    my $idfetch = $self->{storage}->fetch('MetaEntity', { 
							 where => [ entity => $entity, 
								    id     => \qq{Entities.entity}, ],
							},
					  'Entities', {
						       return => "id",
						       where => [ 
								 visual_id => $self->id(),
								] } );
    return $idfetch->[0]->{id};
}

sub get {
  my $class = shift;
  my $visual_id = shift;
  my @time = @_;

  Yggdrasil::fatal("When calling get with a time slice specified, you will recieve a list")
    if @time > 1 && ! wantarray && ! $time[0] == $time[1];
  
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
    
    my $entity = Yggdrasil::_extract_entity($class);
    my $idref = $Yggdrasil::STORAGE->fetch('MetaEntity', { 
							  where => [ entity => $entity, 
								     id     => \qq{Entities.entity}, ],
							 },
					   'Entities', {
							return => "id",
							where => [ visual_id => $visual_id ] } );
    my $id = $idref->[0]->{id};

    # Short circuit the joins if we're looking for the current object
    unless (@time) {
	if ($id) {
	    return { id => $id };
	} else {
	    return;
	}
    }
    
    my $fetchref = $Yggdrasil::STORAGE->fetch('MetaEntity', { where => [
									entity => $entity, 
									id     => \qq<MetaProperty.entity>,
								       ]},
					      "MetaProperty" => { return => "property" },
					      { start => $time[0], stop => $time[1] } );
    
    my @wheres;
    push( @wheres, 'Entities' => { join => "left", where => [ id => $id ] } );
    
    foreach my $prop ( map { $_->{property} } @$fetchref ) {
	my $table = join(":", $entity, $prop);
	push( @wheres, $table => { join => "left" } );
    }

    my $ref = $Yggdrasil::STORAGE->fetch( @wheres, { start => $time[0], stop => $time[1] } );
    
    # If we're within a time slice, filter out the relevant hits, sort
    # them and return.  Remember to set the start of the first hit to
    # $time[0] (the first timestamp in the request) and the end time
    # of the last hit to $time[1] (the last acceptable timestamp in
    # the request.
    if( defined $time[0] || defined $time[1] ) {
	my $times = $class->_filter_start_times( $time[0], $time[1], $ref );

	my @sorted = map { $times->{$_} } sort { $a <=> $b } keys %$times;
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
    my $self   = shift;
    my $entity = $self->_extract_entity();
    
    return Yggdrasil::Property->define( $entity, @_ );
}

# Filter out the unique start times between $start and $stop from all
# the db hits in the $dbref parameter.  
sub _filter_start_times {
    my ($class, $start, $stop, $dbref) = @_;
    
    my %times;
    if (defined $start && defined $stop && $start == $stop && @$dbref) {
	return {
		start => $start,
		stop  => $start
	       };
    }
    
    foreach my $e ( @$dbref ) {
	foreach my $key ( keys %$e ) {
	    next unless $key =~ /_start$/;
	    
	    my $val = $e->{$key};
	    
	    # print "VAL = $key $val $start :: $stop\n";
	    my $good;
	    if( defined $start ) {
		if( defined $stop ) {
		    $good = $start <= $val && $val < $stop;
		} else {
		    $good = $val >= $start if $val && $start;
		}
	    } elsif( defined $stop ) {
		$good = $val < $stop;
	    }
	    
	    if( $good ) {
		# print "GOOD VAL = $val\n";
		$times{$val} = { start => $val };
	    }
	}
    }
    return \%times;
}

sub property {
    my $self = shift;
    my ($key, $value) = @_;

    my $storage = $self->{storage};

    my $entity = $self->_extract_entity();
    my $name = join(":", $entity, $key );

    my $schema = $self->property_exists( $key );

    # This should perhaps be a warning instead (when under strict => 1)
    #Yggdrasil::fatal("Unable to find property '$key' for entity '$entity'.") 
    return undef unless defined $schema;
    
    # Did we get two params, even if one was undef?
    if (@_ == 2) {
	if( defined $self->{_start} || defined $self->{_stop} ) {
	    Yggdrasil::fatal("Temporal objects are immutable.");
	}

	if (! defined $value && ! $self->null( $key )) {
	    Yggdrasil::fatal("$entity :: $key cannot be set to NULL.");
	}

	$storage->store( $schema, key => "id", fields => { id => $self->{_id}, value => $value } );
    }

    my $r = $storage->fetch( $schema => { return => "value", where => [ id => $self->{_id} ] },
			     { start => $self->{_start}, stop => $self->{_stop} } );
    return $r->[0]->{value};
}

sub property_exists {
    my ($self_or_class, $property) = (shift, shift);
    my ($start, $stop) = $self_or_class->_get_times_from( @_ );
    my ($entity);
    
    if (ref $self_or_class) {
	$entity = $self_or_class->_extract_entity();
    } else {
	$entity = Yggdrasil::_extract_entity($self_or_class);
    }
    
    my @ancestors = __PACKAGE__->_ancestors($entity, $start, $stop);
    my $storage = $Yggdrasil::STORAGE;
    
    # Check to see if the property exists.
    foreach my $e ( $entity, @ancestors ) {
	my $aref = $storage->fetch('MetaEntity', { where => [ id     => \qq{MetaProperty.entity},
							      entity => $e,
							    ]},
				   'MetaProperty', { return => 'property',
						     where => [ property => $property ] },
				   { start => $start, stop => $stop });

	# The property name might be "0".
	return join(":", $e, $property) if defined $aref->[0]->{property};
    }
    
    return;
}

sub properties {
    my $class = shift;
    my ($start, $stop) = $class->_get_times_from( @_ );

    if (ref $class) {
	$class = $class->_extract_entity();
    } else {
	$class = Yggdrasil::_extract_entity($class);
    }

    my @ancestors = __PACKAGE__->_ancestors($class, $start, $stop);
    my $storage = $Yggdrasil::STORAGE;

    my %properties;
    
    foreach my $e ( $class, @ancestors ) {
	my $aref = $storage->fetch('MetaEntity', { where => [ id     => \qq{MetaProperty.entity},
							      entity => $e,
							    ]},
				   'MetaProperty', 
				    { return => 'property' },
				    { start  => $start, stop => $stop });
	
	$properties{ $_->{property} } = 1 for @$aref;
    }

    return keys %properties;
}

# FIXME, temporal search.
sub relations {
    my $class = shift;

    if (ref $class) {
	$class = $class->_extract_entity();
    } else {
	$class = Yggdrasil::_extract_entity($class);
    }
    
#    my $lref = $Yggdrasil::STORAGE->fetch( 'MetaRelation', 
#					   { return => 'entity2', 
#					     where => [ entity1 => $class ] 
#					   } );
#    my $rref = $Yggdrasil::STORAGE->fetch( 'MetaRelation', 
#					   { return => 'entity1', 
#					     where => [ entity2 => $class ]
#					   } );
#
#    return map { $_->{entity1} || $_->{entity2} } @$lref, @$rref;    

    # FIXME, needs to check for all parents, not just self.
    
    my $other = $Yggdrasil::STORAGE->fetch('MetaEntity', { where => [ entity => $class ] },
					   'MetaRelation',
					    { return => [ 'label' ],
					      where => [ rval => \qq{MetaEntity.id},
							 lval => \qq{MetaEntity.id} ],
					      bind => "or" 
					    } );


    return map { $_->{label} } @$other
}

# fetches all current instances for an Entity
sub instances {
    my $class = shift;

    if (ref $class) {
	$class = $class->_extract_entity();
    } else {
	$class = Yggdrasil::_extract_entity($class);
    }
    
    my $instances = $Yggdrasil::STORAGE->fetch( 'MetaEntity' => { where  => [ entity => $class ] },
					        'Entities'   => { return => 'visual_id',
								  where => [ entity => \qq{MetaEntity.id} ] } );

    # FIXME, return objects.
    return map { $_->{visual_id} } @$instances;
}


# _get_meta returns meta data for a property, information about nullp
# and type is currently supported.
sub _get_meta {
    my ($class, $property, $meta) = (shift, shift, shift);
    my ($start, $stop) = $class->_get_times_from( @_ );
    
    Yggdrasil::fatal( "$meta is not a valid metadata request." ) 
	unless $meta eq 'null' || $meta eq 'type';

    # The internal name for the null field is "nullp".
    $meta = 'nullp' if $meta eq 'null';

    if (ref $class) {
	$class = $class->_extract_entity();
    } else {
	$class = Yggdrasil::_extract_entity($class);
    }

    my @ancestors = __PACKAGE__->_ancestors($class, $start, $stop);
    my $storage = $Yggdrasil::STORAGE;

    foreach my $e ( $class, @ancestors ) {
	my $ret = $storage->fetch('MetaEntity', { where => [ entity => $e ]},
				  'MetaProperty',{ return => $meta,
						    where  => [ entity   => \qq{MetaEntity.id},
								property => $property ]},
				   { start => $start, stop => $stop });
	next unless @$ret;
	return $ret->[0]->{$meta};
    }
}

# Property null function for non-instanced calls.
# It is called as "Ygg::Entity->null( 'propertyname' );
sub null {
    my ($class, $property) = (shift, shift);
    return $class->_get_meta( $property, 'null', @_ );
}

# Property type function for non-instanced calls.
# It is called as "Ygg::Entity->type( 'propertyname' );
sub type {
    my ($class, $property) = (shift, shift);
    return $class->_get_meta( $property, 'type', @_ );
}

sub search {
    my ($class, $key, $value) = (shift, shift, shift);
    my $package = $class;
    $class = Yggdrasil::_extract_entity($class);
    
    # Passing the possible time elements onwards as @_ to the Storage layer.
    my ($nodes) = $Yggdrasil::STORAGE->search( $class, $key, $value, @_);
    
    my @hits;
    for my $hit (@$nodes) {
	my $obj = $package->SUPER::new();
	for my $key (keys %$hit) {
	    $obj->{$key} = $hit->{$key};
	}
	push @hits, $obj;
    }
    return @hits;
}

sub isa {
    my $self_or_class = shift;
    my $isa = shift;
    my($start, $stop) = $self_or_class->_get_times_from( @_ );

    my $entity;
    if (ref $self_or_class) {
	$entity = $self_or_class->_extract_entity();
    } else {
	$entity = Yggdrasil::_extract_entity($self_or_class);
    }

    $isa = Yggdrasil::_extract_entity($isa) if defined $isa;
    return 1 if defined $isa && $isa eq $entity;

    my $storage = $Yggdrasil::STORAGE;

    my @ancestors = __PACKAGE__->_ancestors($entity, $start, $stop );
    if( defined $isa ) {
	my $r = grep { $isa eq $_ } @ancestors;
	return $r;
    } else {
	return @ancestors;
    }
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
  my($start, $stop) = $self->_get_times_from( @_ );
  
  $relative = Yggdrasil::_extract_entity($relative);
  my $source = $self->_extract_entity();

  my $source_id = $self->{storage}->_get_entity( $source );
  my $destin_id = $self->{storage}->_get_entity( $relative );
  
  my $paths = $self->_fetch_related( $source_id, $destin_id, undef, undef, $start, $stop );

  my %result;
  foreach my $path ( @$paths ) {

      my @schema;
      my $alias_prefix = "R";
      my $alias_num    = 1;
      my $alias;
      my $prev_alias;
      my $alias_generator = sub {
	  return join('', $alias_prefix, $alias_num++);
      };

      my $first = shift @$path;
      $alias = $alias_generator->();
      push( @schema, Relations => {
	  where => [ lval => $self->{_id},
		     rval => $self->{_id} ], 
	  bind => "or",
	  alias => $alias } );
      
      foreach my $step ( @$path ) {
	  $prev_alias = $alias;
	  $alias = $alias_generator->();
	  push( @schema, Relations => { where => [ lval => \qq<$prev_alias.lval>,
						   lval => \qq<$prev_alias.rval>,
						   rval => \qq<$prev_alias.lval>, 
						   rval => \qq<$prev_alias.rval> ], 
					bind => "or", alias => $alias } );
      }

      push(@schema,
	   Entities => { return => "visual_id", 
			 where => [ id     => \qq<$alias.lval>,
				    id     => \qq<$alias.rval> ],
			 bind => "or" },
	   Entities => { where => [ entity => $path->[-1] ] } );

      my $res = $self->{storage}->fetch( @schema, { start => $start, stop => $stop } );

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


sub _fetch_related {
  my $self = shift;
  my $start = shift;
  my $stop = shift;
  my $path = [ @{ shift || [] } ];
  my $all = shift || [];
  my($tstart, $tstop) = $self->_get_times_from( @_ );

  my $storage = $self->{storage};

  # This is less than pretty, but we're checking if we're going within
  # the same entity.
  if (! @$path) {
      if ($start eq $stop) {
	  return [ [ $start, $stop ] ];
      }
  }
  
  return if grep { $_ eq $start } @$path;
  push( @$path, $start );

  return $path if $start eq $stop;

  my $other = $storage->fetch( 'MetaRelation',
			       { return => [ qw/lval rval/ ],
				 where => [ lval => $start,
					    rval => $start ],
				 bind => "or"
			       }, { start => $tstart, stop => $tstop } );

  my @siblings = map { $_->{lval} eq $start ? $_->{rval} : $_->{lval} } @$other;
  foreach my $child ( @siblings ) {
      my $found_path = $self->_fetch_related( $child, $stop, $path, $all, $tstart, $tstop );
      
      push( @$all, $found_path ) if $found_path;
  }

  return $all if @$path == 1;
}


sub _ancestors {
    my $class = shift;
    my $entity = shift;
    my ($start, $stop) = @_;

    my $storage = $Yggdrasil::STORAGE;
    $entity = $storage->get_entity_id( $entity );
    
    my @ancestors;
    my %seen = ( $entity => 1 );

    my $r = $storage->fetch( 'MetaInheritance', { return => "parent", where => [ child => $entity ] },
			     { start => $start, stop => $stop });

    while( @$r ) {
	my $parent = $r->[0]->{parent};
	last if $seen{$parent};
	$seen{$parent} = 1;
	push( @ancestors, $storage->get_entity_name( $parent ) );

	$r = $storage->fetch( 'MetaInheritance', { return => "parent", where => [ child => $parent ] },
			      { start => $start, stop => $stop } );
    }

    return @ancestors;
}

sub _get_times_from {
    my $self_or_class = shift;

    if (@_ == 1) {
	return ($_[0], $_[0]);
    } elsif (@_ == 2) {
	return ($_[0], $_[1]);
    } else {
	return ();
    }
} 

1;
