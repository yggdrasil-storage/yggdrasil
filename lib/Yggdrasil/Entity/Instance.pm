package Yggdrasil::Entity::Instance;

use base 'Yggdrasil::Object';

use Yggdrasil::Utilities;

use strict;
use warnings;

sub create {
    my $class  = shift;
    my $self   = $class->SUPER::new(@_);
    my %params = @_;

    my $vid    = $self->{visual_id} = $params{id};
    my $entity = $self->{entity}    = $params{entity};

    # Check if the instance already exists
    my $status = $self->get_status();
    my $ename  = $entity->name();

    my $instance = __PACKAGE__->fetch( yggdrasil => $self, %params );
    if( $instance ) {
	$status->set( 202, "Instance '$vid' already existed for entity '$ename'." );
	return $instance;
    }

    # Create the instance
    # FIX: Want to avoid having to query MetaEntity for the entity's
    #      id. Couldn't Entity-objects have an ->_id() or similar
    #      method that returns this number?
    my $idref = $self->storage()->fetch( 
	MetaEntity => { return => 'id', where  => [ entity => $ename ] } );

    my $eid = $idref->[0]->{id};

    $self->{_id} = $self->storage()->store( Entities => 
					    fields => { visual_id => $vid,
							entity    => $eid } );

    $status->set( 201, "Created instance '$vid' in entity '$ename'." );
    return $self;
}

sub entity {
    my $self = shift;
    
    return $self->{entity};
}

sub fetch {
    my $class  = shift;
    my $self   = $class->SUPER::new(@_);
    my %params = @_;

    my $vid    = $self->{visual_id} = $params{id};
    my $entity = $self->{entity}    = $params{entity};
    my $time   = $params{time} || [];

    my $ename = $entity->name();

    my $status = $self->get_status();

    # Check if instance exists
    my $id = $self->_get_id();
    unless( $id ) {
	$status->set( 404, "Instance '$vid' not found in entity '$ename'." );
	return;
    }

    if( @$time > 1 && ! wantarray && $time->[0] != $time->[1] ) {
	$status->set( 406, "When calling fetch with a time slice specified a list will be returned" );
	return;
    }

    # If the user only specifies one time argument, then stop should
    # be set equal to start, meaning fetch is called for a specific
    # moment in time.
    push( @$time, $time->[0] ) if @$time == 1;

    my @instances;
    for my $dataref ( $self->_get_in_time($vid, @$time) ) {
	# UGH ...
	my $o = __PACKAGE__->new( yggdrasil => $self );
	$o->{visual_id} = $vid;
	$o->{_id}       = $id;
	$o->{_start}    = $dataref->{start};
	$o->{_stop}     = $dataref->{stop};
	$o->{entity}    = $entity;

	push( @instances, $o );
    }

    $status->set( 200 );
    if( @$time && $time->[0] && $time->[1] && $time->[0] != $time->[1] ) {
	return @instances;
    } else {
	return $instances[-1];
    }
}

sub delete :method {
    my $class  = shift;
    my $self   = $class->SUPER::new(@_);
    my %params = @_;

    # FIX: write this method
    #      expire the instance (as well as all it's property values?)
}

sub _get_id {
    my $self = shift;
    my $entity = $self->{entity};

    my $idfetch = $self->storage()->fetch(
	MetaEntity => { 
	    where => [ entity => $entity->name(), 
		       id     => \qq{Entities.entity} ]	},
	Entities   => {
	    return => "id",
	    where => [ visual_id => $self->id() ] } );

    return $idfetch->[0]->{id};
}


sub _get_in_time {    
    my $self = shift;
    my $visual_id = shift;
    my @time = @_;

    my $entity = $self->{entity};

    # FIX: Do we really need to perform this query?
    #      Can't we just check $self->{_id}?
    my $idref  = $self->storage()->fetch('MetaEntity', { 
							where => [ entity => $entity->name(), 
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
    
    my $fetchref = $self->storage()->fetch(
	MetaEntity   => { where => [ entity => $entity->name(), 
				     id     => \qq<MetaProperty.entity> ] },
	MetaProperty => { return => "property" },
	{ start => $time[0], stop => $time[1] } );
    
    my @wheres;
    push( @wheres, 'Entities' => { join => "left", where => [ id => $id ] } );
    
    foreach my $prop ( map { $_->{property} } @$fetchref ) {
	my $table = join(":", $entity->name(), $prop);
	push( @wheres, $table => { join => "left" } );
    }

    my $ref = $self->storage()->fetch( @wheres, { start => $time[0], stop => $time[1] } );

    # If we're within a time slice, filter out the relevant hits, sort
    # them and return.  Remember to set the start of the first hit to
    # $time[0] (the first timestamp in the request) and the end time
    # of the last hit to $time[1] (the last acceptable timestamp in
    # the request.
    if( defined $time[0] || defined $time[1] ) {
	my $times = $self->_filter_start_times( $time[0], $time[1], $ref );

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
    my $entity = $self->{entity};
    
    return Yggdrasil::Property->define( $entity, @_ );
}

# Filter out the unique start times between $start and $stop from all
# the db hits in the $dbref parameter.  
sub _filter_start_times {
    my ($self, $start, $stop, $dbref) = @_;

    if (defined $start && defined $stop && $start == $stop && @$dbref) {
	return { $start => {
	    start => $start,
	    stop  => $start
		 }
	};
    }
    
    my %times;
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

sub get {
    my $self = shift;
    return $self->property( @_ );
}

sub set {
    my $self = shift;
    return $self->property( @_ );
}

sub property {
    my $self = shift;
    my ($key, $value) = @_;

    my $storage = $self->storage();

    my $entity = $self->{entity};
    my $name = join(":", $entity->name(), $key );

    my $p = Yggdrasil::Property->get( yggdrasil => $self, entity => $entity->name(), property => $key );

    my $status = $self->get_status();
    
    unless ($p) {
	$status->set( 404, "Unable to find property '$key' for entity '" . $entity->name() . "'" );
	return undef;
    }

    # FIX: Sadly, $p->full_name doesn't deal with inheritance properly.
    my $schema = $entity->property_exists( $key );
    # Did we get two params, even if one was undef?
    if (@_ == 2) {
	if( defined $self->{_start} || defined $self->{_stop} ) {
	    $status->set( 406, "Temporal objects are immutable.");
	    return undef;
	}

	# FIXME, $self->null is void, need to get $prop->null

	unless ( $p ) {
	    $status->set( 404, "Property '$key' not defined for '" . $entity->name() . "'" );
	    return;
	}

	if (! defined $value && ! $p->null() ) {
	    $status->set( 406, "Property does not allow NULL values.");
	    return undef;
	}

	$storage->store( $schema, key => "id", fields => { id => $self->{_id}, value => $value } );
    }

    my $r = $storage->fetch( $schema => { return => "value", where => [ id => $self->{_id} ] },
			     { start => $self->{_start}, stop => $self->{_stop} } );

    if ($r->[0]->{value}) {
	# Pass through return value from Storage, it'll be 200 / 202 correctly.
	# $status->set( 200 );
    } else {
	$status->set( 204 ) if $status->OK();
    }

    return $r->[0]->{value};
}

# FIXME, temporal search.  FIXME, JUST FIX ME!
# FIX: Should this be moved to Y::Entity?
sub relations {
    my $self = shift;

    if (ref $self) {
	$self = $self->{entity};
    } else {
	$self = Yggdrasil::_extract_entity($self);
    }
    
#    my $lref = $Yggdrasil::STORAGE->fetch( 'MetaRelation', 
#					   { return => 'entity2', 
#					     where => [ entity1 => $self ] 
#					   } );
#    my $rref = $Yggdrasil::STORAGE->fetch( 'MetaRelation', 
#					   { return => 'entity1', 
#					     where => [ entity2 => $self ]
#					   } );
#
#    return map { $_->{entity1} || $_->{entity2} } @$lref, @$rref;    

    # FIXME, needs to check for all parents, not just self.
    
    my $other = $self->storage()->fetch('MetaEntity', { where => [ entity => $self ] },
					   'MetaRelation',
					    { return => [ 'label' ],
					      where => [ rval => \qq{MetaEntity.id},
							 lval => \qq{MetaEntity.id} ],
					      bind => "or" 
					    } );


    return map { $_->{label} } @$other
}



sub is_a {
    my $self = shift;
    my $isa = shift;
    my($start, $stop) = Yggdrasil::Utilities::get_times_from( @_ );

    my $entity = $self->{entity};
    my $storage = $self->{yggdrasil}->{storage};

    return 1 if $isa eq $entity->name();

    my @ancestors = Yggdrasil::Utilities::ancestors($storage, $entity->name(), $start, $stop);

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


# FIXME, set status values!
sub fetch_related {
  my $self = shift;
  my $relative = shift;
  my($start, $stop) = Yggdrasil::Utilities::get_times_from( @_ );

  # FIX: relative can either be an Y::E object or the name of an Entity
  #      for now, only objects

  my $source = $self->{entity};

  my $source_id = $self->storage()->_get_entity( $source->name() );
  my $destin_id = $self->storage()->_get_entity( $relative->name() );
  
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

      my $res = $self->storage()->fetch( @schema, { start => $start, stop => $stop } );

      foreach my $r ( @$res ) {
	  my $obj = $relative->fetch( $r->{visual_id} );
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
  my($tstart, $tstop) = (shift, shift);

  my $storage = $self->storage();

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

  # FIXME, what do we do if we get 403 returned here?  Not that we
  # will, currently MetaRelation has _global_read_access set to true.  
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

1;
