package Yggdrasil::Local::Instance;

use Yggdrasil::Utilities;

use strict;
use warnings;

use base qw/Yggdrasil::Instance/;

sub create {
    my $class  = shift;
    my $self   = $class->SUPER::new(@_);
    my %params = @_;

    my $vid    = $self->{visual_id} = $params{instance};
    my $entity = $self->{entity}    = $params{entity};

    # Check if the instance already exists
    my $status = $self->get_status();
    my $ename  = $entity->_userland_id();

    # Can't create historic object
    if( $entity->stop() ) {
	$status->set( 406, "Unable to create instances in historic context" );
	return;
    }

    my $instance = __PACKAGE__->fetch( yggdrasil => $self, %params );
    if( $instance ) {
	$status->set( 202, "Instance '$vid' already existed for entity '$ename'." );
	return $instance;
    }

    # Create the instance
    # FIX: Want to avoid having to query MetaEntity for the entity's
    #      id. Couldn't Entity-objects have an ->_id() or similar
    #      method that returns this number?

    my $transaction = $self->storage()->initialize_transaction();
    
    my $idref = $self->storage()->fetch( 
	MetaEntity => { return => 'id', where  => [ entity => $ename ] } );

    unless ($self->get_status()->OK()) {
	$transaction->rollback();
	return;
    }

    my $eid = $idref->[0]->{id};
    $self->{_id} = $self->storage()->store( Instances => 
					    key => [qw/visual_id entity/],
					    fields => { visual_id => $vid,
							entity    => $eid } );
    if ($self->get_status()->OK()) {
	$status->set( 201, "Created instance '$vid' in entity '$ename'." );
	$transaction->commit();
	return __PACKAGE__->fetch( yggdrasil => $self, %params );
    } else {
	$transaction->rollback();
	return;
    }
}

sub fetch {
    my $class  = shift;
    my $self   = $class->SUPER::new(@_);
    my %params = @_;

    my $vid    = $self->{visual_id} = $params{instance};
    my $entity = $self->{entity}    = $params{entity};

    my $ename = $entity->_userland_id();
    my $status = $self->get_status();

    $self->{_start} = $entity->start();
    $self->{_stop}  = $entity->stop();

    my $time = $self->_validate_temporal( $params{time} );
    return unless $time;

    # Check if instance exists
    my $id = $self->_get_id($time);
    unless( $id ) {
	$status->set( 404, "Instance '$vid' not found in entity '$ename'." );
	return;
    }

    my @instances;
    for my $dataref ( $self->_get_in_tick($vid, $time) ) {
	# UGH ...
	my $o = __PACKAGE__->new( yggdrasil => $self );
	$o->{visual_id}  = $vid;
	$o->{_id}        = $id;
	$o->{_start}     = $time->{start} || $dataref->{start};
	$o->{_stop}      = $time->{stop} || $dataref->{stop};
	$o->{_realstart} = $dataref->{start};
	$o->{_realstop}  = $dataref->{stop};
	$o->{entity}     = $entity;
	push( @instances, $o );
    }

    $status->set( 200 );
    if( wantarray ) {
	return @instances;
    } else {
	return $instances[-1];
    }
}

# FIXME, return values from expire / _expire.  What do we do with
# multiple calls like the loop for properties?  We can only send one
# return value back to userland... This should be a singular
# transaction, right?  Rollback on failure?
sub expire {
    my $self = shift;

    my $storage = $self->storage();
    my $entity  = $self->entity();
    my $status  = $self->get_status();

    # Can't expire historic object
    if( $self->stop() ) {
	$status->set( 406, "Unable to expire instances in historic context" );
	return;
    }

    my $transaction = $storage->initialize_transaction();
    
    # Expire all properties
    for my $prop ($entity->properties()) {
	$storage->expire( join(':', $entity->_userland_id(), $prop->_userland_id()), id => $self->{_id} );

	unless ($status->OK()) {
#	    $transaction->rollback();
#	    return;
	}
    }
    
    # Expire the instance itself.
    $storage->expire( 'Instances', id => $self->{_id} );
    if ($status->OK()) {
	$transaction->commit;
	return 1;
    } else {
	$transaction->rollback();
	return;
    }
    
}

sub _get_id {
    my $self = shift;
    my $time = shift;
    my $entity = $self->{entity};

    my $idfetch = $self->storage()->fetch(
	MetaEntity => { 
	    where => [ entity => $entity->_userland_id(), 
		       id     => \qq{Instances.entity} ]	},
	Instances   => {
	    return => "id",
	    where => [ visual_id => $self->id() ] },
        $time );

    return $idfetch->[0]->{id};
}


sub _get_in_tick {    
    my $self = shift;
    my $visual_id = shift;
    my $time = shift;

    my $entity = $self->{entity};

    # FIX: Do we really need to perform this query?
    #      Can't we just check $self->{_id}?
    my $idref  = $self->storage()->fetch('MetaEntity', { 
							where => [ entity => $entity->_userland_id(), 
								   id     => \qq{Instances.entity}, ],
						       },
					 'Instances', {
						      return => [ "id", 'start', 'stop' ],
						      where => [ visual_id => $visual_id ] },
					 $time );

    my $id = $idref->[0]->{id};
    
    # Short circuit the joins if we're looking for the current object
    unless( $self->stop() ) {
	if ($id) {
	    return { id => $id, 'start' => $idref->[0]->{start}, 'stop' => $idref->[0]->{stop} };
	} else {
	    return;
	}
    }

    my $fetchref = $self->storage()->fetch(
					   MetaEntity   => { where => [ entity => $entity->_userland_id(), 
									id     => \qq<MetaProperty.entity> ]},
					   MetaProperty => { return => "property" },
					   $time );
    
    my @wheres;
    push( @wheres, 'Instances' => { join => "left",
				    return => '*',
				    where => [ id => $id ] } );

    my %seen_props;
    foreach my $prop ( map { $_->{property} } @$fetchref ) {
	next if $seen_props{ $prop }++;
 	my $table = join(":", $entity->_userland_id(), $prop);
 	push( @wheres, $table => { join => "left", return => '*' } );
     }
    
    my $ref = $self->storage()->fetch( @wheres, $time );

    # If we're within a time slice, filter out the relevant hits, sort
    # them and return.  Remember to set the start of the first hit to
    # $time->{start} (the first timestamp in the request) and the end
    # time of the last hit to $time->{stop} (the last acceptable
    # timestamp in the request.    
     if( defined $time->{start} || defined $time->{stop} ) {
 	my $times = $self->_filter_start_times( $time->{start}, $time->{stop}, $ref );

 	my @sorted = map { $times->{$_} } sort { $a <=> $b } keys %$times;
 	for( my $i = 0; $i < @sorted; $i++ ) {
 	    my $e = $sorted[$i];
 	    my $next = $sorted[$i+1] || {};
	    
#	    if( $i == 0 ) {
#		$e->{start} = $time->{start};
#	    }

 	    $e->{stop} = $next->{start} || $time->{stop};
 	}
 	return @sorted;
     }
    
    return @$ref;
}

sub _define {
    my $self   = shift;
    my $entity = $self->{entity};
    
    return Yggdrasil::Local::Property->define( $entity, @_ );
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
	    next unless defined $val;
	    
	    # print "VAL = $key $val $start :: $stop\n";
	    my $good;
	    if( defined $start ) {
		if( defined $stop ) {
		    my $event_stop = $key;
		    $event_stop =~ s/_start$/_stop/;
		    my $event_stop_val = $e->{$event_stop};
		    $good = (($start <= $val && $val < $stop)
			     ||
			     ($val <= $stop && ! defined $event_stop_val));
		} else {
		    $good = $val >= $start if $val && defined $start;
		}
	    } elsif( defined $stop ) {
		$good = $val < $stop;
	    }
	    
	    if( $good ) {
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

sub property_history {
    my $self = shift;
    my $key  = shift;
    my %params = @_;
    my $p;

    my $time = $self->_validate_temporal( $params{time} );
    return unless $time;

    # have to set stop to get history instead of current properties
    $time->{stop} ||= $self->yggdrasil()->current_tick();
    $time->{start} ||= $self->start();

    # We might be passed a property object and not its name as the
    # key.  Also verify that it's of the correct class.
    my $status = $self->get_status();
    if (ref $key) {
	if (ref $key eq 'Yggdrasil::Local::Property') {
	    $p = $key;
	    $key = $p->_userland_id();
	} else {
	    my $ref = ref $key;
	    $status->set( 406, "$ref isn't acceptable as a property reference." );
	    return;
	}
    }

    my $storage = $self->storage();
    my $entity = $self->{entity};
    my $name = join(":", $entity->_userland_id(), $key );

    $p = Yggdrasil::Local::Property->get( yggdrasil => $self, entity => $entity, property => $key, time => $time )
      unless $p;
    
    unless ($p) {
	$status->set( 404, "Unable to find property '$key' for entity '" . $entity->_userland_id() . "'" );
	return;
    }

    my $schemaref = $entity->property_exists( $key, time => $time );
    my $schema    = $schemaref->{name};
 
    my $r = $storage->fetch( $schema => { return => ["start", "value"], 
					  as => 1, 
					  where => [ id => $self->{_id} ] }, 
			     $time );

    if( @$r ) {
	my %history;
	foreach my $entry (@$r) {
	    $history{ $entry->{$schema . '_start'} } = $entry->{value};
	}

	return %history;
    }

    return;
}

sub property {
    my $self = shift;
    my ($key, $value) = @_;
    my $p;

    my $time;
    if (@_ == 3) {
	# get( key, time, {} ), ie, value is "time".
	$time = $self->_validate_temporal( $_[2] );
    } else {
	$time = $self->_validate_temporal();
    }
    return unless $time;
    
    # We might be passed a property object and not its name as the
    # key.  Also verify that it's of the correct class.
    my $status = $self->get_status();
    if (ref $key) {
	if (ref $key eq 'Yggdrasil::Local::Property') {
	    $p = $key;
	    $key = $p->_userland_id();
	} else {
	    my $ref = ref $key;
	    $status->set( 406, "$ref isn't acceptable as a property reference." );
	    return undef;
	}
    }

    my $storage = $self->storage();

    my $entity = $self->{entity};
    my $name = join(":", $entity->_userland_id(), $key );

    $p = Yggdrasil::Local::Property->get( yggdrasil => $self, entity => $entity, property => $key, time => $time )
      unless $p;
    
    unless ($p) {
	$status->set( 404, "Unable to find property '$key' for entity '" . $entity->_userland_id() . "'" );
	return undef;
    }

    my $schemaref = $entity->property_exists( $key, time => $time );
    my $schema    = $schemaref->{name};
    # Did we get two params, even if one was undef?
    if (@_ == 2) {
	if( defined $self->{_stop} ) {
	    $status->set( 406, "Temporal objects are immutable.");
	    return undef;
	}

	# FIXME, $self->null is void, need to get $prop->null

	unless ( $p ) {
	    $status->set( 404, "Property '$key' not defined for '" . $entity->_userland_id() . "'" );
	    return;
	}

	if (! defined $value && ! $p->null() ) {
	    $status->set( 406, "Property does not allow NULL values.");
	    return undef;
	}

	# Stricktly speaking, there is no need to make a transaction
	# for a single Storage::store(), as Storage is more than
	# capable of doing that on its own, but it's nice to be
	# explicit about things.
	my $transaction = $storage->initialize_transaction();
	$storage->store( $schema, key => "id", fields => { id => $self->{_id}, value => $value } );
	
	if ($status->OK()) {
	    $transaction->commit();
	    return $value;
	} else {
	    $transaction->rollback();
	    return;
	}
    }

    my $r = $storage->fetch( $schema => { return => [qw/id value/], where => [ id => $self->{_id} ] },
			     $time );

    if (@$r < 2) {
	if( ! defined $r->[0]->{id} ) {
	    $status->set( 210 );
	    return;
	}
	
	if ($r->[0]->{value}) {
	    # Pass through return value from Storage, it'll be 200 / 202 correctly.
	    # $status->set( 200 );
	} else {
	    $status->set( 204 ) if $status->OK();
	}

	return $r->[0]->{value};
    } else {
	$status->set( 220 );
	my @values;
	for my $v (@$r) {
	    push @values, $v->{value};	    
	}

	if (wantarray) {
	    return @values;	    
	} else {
	    return $values[-1];
	}
    }
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


    return map { $_->{label} } @$other;
}

sub is_a {
    my $self = shift;
    my $isa = shift;
    my %params = @_;

    my $entity = $self->{entity};
    my $storage = $self->{yggdrasil}->{storage};

    return 1 if $isa eq $entity->_userland_id();

    my @ancestors = $entity->ancestors( $params{time} );

    if( defined $isa ) {
	my $r = grep { $isa eq $_ } @ancestors;
	return $r;
    } else {
	return @ancestors;
    }
}

sub pathlength {
    my $self = shift;
    return $self->{_pathlength};
}


# FIXME, set status values!
sub fetch_related {
  my $self = shift;
  my $relative = shift;

    my $time = $self->_validate_temporal( {} );
    return unless $time;  

  # FIX: relative can either be an Y::E object or the name of an Entity
  #      for now, only objects
  my $source = $self->{entity};
  my $paths = $self->_fetch_related( $source->{_id}, $relative->{_id}, undef, undef, $time );

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
      my @id = ( $self->{_id} );
      my $res;
      foreach my $step ( @$path ) {
	  my $alias = $alias_generator->();
	  my @schema = ( Relations => {
				       where  => [ lval => \@id,
						   rval => \@id ], 
				       bind   => "or",
#				       noauth => 1,
				      } );
	  
#	  push( @schema, Relations => { where  => [ lval => \qq<Relations.lval>,
#						    lval => \qq<Relations.rval>,
#						    rval => \qq<Relations.lval>, 
#						    rval => \qq<Relations.rval> ], 
#					bind   => "or",
#					alias  => $alias,
#					noauth => 1,
#				      } );

	  push(@schema,
	       Instances => { return => [ qw/id visual_id/ ], 
			      where  => [ id     => \qq<Relations.lval>,
					  id     => \qq<Relations.rval> ],
			      bind   => "or",
#			      noauth => 1,
			    },
	       Instances => { # noauth => 1,
			      where  => [ entity => $step ] } );

	  $res = $self->storage()->fetch( @schema, $time );
	  @id = map { $_->{id} } @$res;
	  last unless @id;
      }


      foreach my $r ( uniq(map { $_->{visual_id} } @$res) ) {
	  my $obj = $relative->fetch( $r );
	  $obj->{_pathlength} = scalar @$path - 1;
      
	  $result{ $r } = $obj;
      }
  }
  
  return sort { $a->{_pathlength} <=> $b->{_pathlength} } values %result;
}


sub _fetch_related {
  my $self = shift;
  my $first = shift;
  my $last = shift;
  my $path = [ @{ shift || [] } ];
  my $all = shift || [];
  my $time = shift;

  my $storage = $self->storage();

  # This is less than pretty, but we're checking if we're going within
  # the same entity.
  if (! @$path) {
      if ($first eq $last) {
	  return [ [ $first, $last ] ];
      }
  }
  
  return if grep { $_ eq $first } @$path;
  push( @$path, $first );

  return $path if $first eq $last;

  # Fetch links which on either side has $first as it's value. Filter
  # out the side which does not has $first, and use this as the new
  # $first, in this way we build up a possible path from $first to
  # $last
  my $other = $storage->fetch( 'MetaRelation',
			       { return => [ qw/lval rval/ ],
				 where => [ lval => $first,
					    rval => $first ],
				 bind => "or"
			       }, $time );

  my @siblings = uniq( map { $_->{lval} eq $first ? $_->{rval} : $_->{lval} } @$other );
  foreach my $child ( @siblings ) {
      my $found_path = $self->_fetch_related( $child, $last, $path, $all, $time );
      
      push( @$all, $found_path ) if $found_path;
  }

  return $all if @$path == 1;
}

# FIXME: have a distinct/uniq flag we can send with fetch? or why with
# the new auth stuff do we get so many duplicates?
sub uniq {
    return unless @_;

    my @sort = sort @_;
    my @uniq = shift @sort;
    for my $e ( @sort ) {
	push( @uniq, $e ) unless $uniq[-1] eq $e;
    }
    return @uniq;
}

1;
