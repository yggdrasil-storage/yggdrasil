package Yggdrasil::Storage::SQL;

use strict;
use warnings;

use Carp;

sub entities {
    my $self = shift;
    my @entities;
    
    my $e = $self->dosql_select( "SELECT * FROM MetaEntity WHERE stop is null" );

    for my $row ( @$e ) {
	push @entities, $row->{entity};
    }
    return @entities;
}

sub relations {
  my $self = shift;
  my @relations;

  my $e = $self->dosql_select( "SELECT * FROM MetaRelation WHERE stop is null" );

  for my $row ( @$e ) {
    push( @relations, [ $row->{entity1}, $row->{entity2}, $row->{relation} ] );
  }

  return @relations;
}

sub get_relations {
  my $self = shift;
  my $relation = shift;

  my $e = $self->dosql_select( "SELECT * FROM MetaRelation WHERE stop is null and (entity1 = ? or entity2 = ?)",
			       [$relation, $relation] );

  my @children;
  for my $row ( @$e ) {
    push( @children, $row->{entity1} eq $relation ? $row->{entity2} : $row->{entity1} );
  }

  return @children;
}

sub properties {
    my $self = shift;
    my $entity = shift;
    my @props;

    my $e = $self->dosql_select( "SELECT * FROM MetaProperty WHERE stop is null and entity = ? ", [ $entity ] );
    for my $row (@$e) {
	my $prop = $row->{property};
	push @props, $prop unless $prop =~ /^_/;
    }
    return @props;
}

sub _prepare_sql {
  my $self = shift;
  my $sql  = shift;
  my $data = shift;

  $sql =~ s/\[(.+?)\]/$data->{$1}/ge; #'"/

  print $sql, "\n";

  return $sql;
}

sub dosql_select {
  my $self = shift;
  my $sql  = shift;
  my $args;
  $args = pop if ref $_[-1] eq "ARRAY";
  
  $sql = $self->_prepare_sql( $sql, @_ );

  my $sth = $self->{dbh}->prepare( $sql );
  confess( "no sth?" ) unless $sth;

  my $args_str = join(", ", map { defined()?$_:"NULL" } @$args);
  print " Args: [$args_str]\n";

  $sth->execute(@$args) 
    || confess( "execute??" );

  return $sth->fetchall_arrayref( {} );
}

sub dosql_update {
  my $self = shift;
  my $sql  = shift;

  my $args;
  $args = pop if ref $_[-1] eq "ARRAY";

  if ($sql =~ /^CREATE TABLE/) {
      $sql = $self->_table_filter( $sql );
  } elsif ($sql =~ /^UPDATE/) {
      $sql = $self->_update_filter( $sql );
  }
  
  $sql = $self->_prepare_sql( $sql, @_ );

  my $sth = $self->{dbh}->prepare( $sql );
  confess( "failed to prepare '$sql'") unless $sth;

  my $args_str = join(", ", map { defined()?$_:"NULL" } @$args);
  print " Args: [$args_str]\n";

  $sth->execute(@$args) 
    || confess( "failed to execute '$sql' with arguments [$args_str]" );

  return $self->_get_last_id( $sql );
}

sub exists {
    my $self      = shift;
    my $structure = shift;
    my $id        = shift;
    my $subkey    = shift || '';

    print "SQL::Exists( $self, $structure, $id, $subkey)\n";

    if ($structure =~ s/^Yggdrasil:://) {
	print "$structure\n";
	if ($structure eq 'Relation' || $structure eq 'Entity') {
	    my $table = "Meta$structure";
	    my $field = lc $structure;
	    my $e = $self->dosql_select( "SELECT * FROM $table WHERE stop is null and $field = ?", [ $id ] );
	    print $e->[0]->{$field}?"HIT":"MISS", "\n";
	    return $e->[0]->{$field};
	} elsif ($structure eq 'Property') {
	    my $e = $self->dosql_select( "SELECT * FROM MetaProperty WHERE stop is null and entity = ? and property = ?", [ $id, $subkey ] );
	    return $e->[0]->{property};
	}
    } else {
	my $e = $self->dosql_select( "SELECT * FROM $structure WHERE visual_id = ? ", [ $id ] );
	return $e->[0]->{id} || undef;
    }
    return undef;
}

sub fetch {
  my $self = shift;
  my $schema = shift;
  my %data = @_;

  my $e;
  if( $schema eq "MetaRelation" ) {
    $e = $self->dosql_select( "SELECT * FROM $schema WHERE stop is null and ( (entity1 = ? and entity2 = ?) or ( entity1 = ? and entity2 = ?) ) ", [ $data{entity1}, $data{entity2}, $data{entity2}, $data{entity1}] );
    
    return $e->[0]->{relation};
  }
  elsif(  $schema =~ /_/ ) {
      my ($entity, $property) = split /_/, $schema;
      return undef unless $self->exists( "Yggdrasil::Property", $entity, $property );
      
      $e = $self->dosql_select( "SELECT * FROM $schema WHERE stop is null and id = ?", [$data{id}] );
      return $e->[0]->{value};
    
  } else {
    $e = $self->dosql_select( "SELECT * FROM $schema WHERE visual_id = ?", [$data{visual_id}] );
    return $e->[0]->{id};
  }
}

sub expire {
  my $self = shift;
  my $schema = shift;
  my %data = @_;

  $self->dosql_update( "UPDATE $schema SET stop = NOW() WHERE stop is null and ( (lval = ? and rval = ?) or (lval = ? and rval = ?) )", [$data{lval}, $data{rval}, $data{rval}, $data{lval}] );
}


sub update {
    my $self = shift;
    my $schema = shift;
    my %data = @_;

    my $e;
    # --- 1. Check for previous value
    if( $schema eq "MetaProperty" ) {
      $e = $self->dosql_select( "SELECT * FROM $schema WHERE stop is null and entity = ? and property = ?", [$data{entity}, $data{property} ] )
    }
    elsif( $schema eq "MetaRelation" ) {
      $e = $self->dosql_select( "SELECT * FROM $schema WHERE stop is null and (entity1 = ? and entity2 = ?) or (entity1 = ? and entity2 = ?) and (requirement != ? or 1=1)", [ $data{entity1}, $data{entity2}, $data{entity2}, $data{entity1}, 0] );
    }
    elsif( $schema eq "MetaEntity" ) {
	$e = $self->dosql_select( "SELECT * FROM $schema WHERE stop is null and entity = ?", [$data{entity}] );
    }
    elsif( $schema =~ /_R_/ ) {
	$e = $self->dosql_select( "SELECT * FROM $schema WHERE stop is null and ( (lval = ? and rval = ?) or (rval = ? and lval = ?) )", [ $data{lval}, $data{rval}, $data{lval}, $data{rval} ] );
	my $h = $e->[0];
	return $h->{id} if $h->{id};
    }
    # Do we have an active property value that's different from the one we're trying to insert.
    elsif( $schema =~ /_/ ) {
      $e = $self->dosql_select( "SELECT * FROM $schema WHERE stop is null and id = ? and value != ?", [$data{id}, $data{value}] );
      
      # Are we trying to insert the exact same value for the same property again?
      # If so, do nothing and return the ID of the previous entry.
      if (! @$e) {
	  my $old = $self->dosql_select( "SELECT * FROM $schema WHERE stop is null and id = ? and value = ?", [$data{id}, $data{value}] );
	  return $old->[0]->{id} if $old->[0]->{id};
      }
    }
   else {
      $e = $self->dosql_select( "SELECT * FROM $schema WHERE visual_id = ?", [$data{visual_id}] );
    }


    # --- 1a. if exists set "end" to NOW()
#    use Data::Dumper;
#    print "*", Dumper( $e ), "\n";
    if( @$e ) {
      if(  $schema =~ /_R_/ || $schema =~ /_/ || grep { $schema eq $_ } 'MetaProperty', 'MetaEntity', 'MetaRelation', 'MetaInheritance' ) {
	my $row = shift @$e;
	my @fields;
	my @values;
	foreach my $key ( keys %$row ) {
	    if (! defined $row->{$key}) {
		push( @fields, "$key is NULL" );
	    } else {
		push( @fields, join('=', $key, "?") );
		push( @values, $row->{$key} );
	    }
	}
	my $where = join(" and ", @fields);
	
	$self->dosql_update( "UPDATE $schema SET stop = NOW() WHERE $where", \@values );
      } else {
	print "Why here?\n";
	return $e->[0]->{id};
      }
    }

    # --- 2. Insert
    my $columns  = join(", ", keys %data);
    my $question = join(", ", ("?") x keys %data);

      if( $schema =~ /_R_/ || $schema =~ /_/ || grep { $schema eq $_ } 'MetaProperty', 'MetaEntity', 'MetaRelation', 'MetaInheritance'   ) {

	return $self->dosql_update( "INSERT INTO $schema($columns, start) VALUES($question, NOW())", [values %data] );
      } else {
	return $self->dosql_update( "INSERT INTO $schema($columns) VALUES($question)", [values %data] );
      }
}

sub _table_filter {
    my $self = shift;
    return $_[0];
}

sub _update_filter {
    my $self = shift;
    return $_[0];
}

1;

