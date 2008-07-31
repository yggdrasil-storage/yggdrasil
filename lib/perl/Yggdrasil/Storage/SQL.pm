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

sub get_entity {
    my $self = shift;
    my $name = shift;

    my $e = $self->dosql_select( "SELECT * FROM MetaEntity WHERE stop is null and entity = ?", [ $name ] );

    return $e->[0]->{entity};
}

sub get_relation {
    my $self = shift;
    my $name = shift;

    my $e = $self->dosql_select( "SELECT * FROM MetaRelation WHERE stop is null and relation = ?", [ $name ] );

    return $e->[0]->{relation};

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

sub get_property {
    my $self     = shift;
    my $entity   = shift;
    my $property = shift;

    my $e = $self->dosql_select( "SELECT * FROM MetaProperty WHERE stop is null and entity = ? and property = ?", [ $entity, $property ] );
    
    return $e->[0]->{property};
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
  
  $sql = $self->_prepare_sql( $sql, @_ );

  my $sth = $self->{dbh}->prepare( $sql );
  confess( "failed to prepare '$sql'") unless $sth;

  my $args_str = join(", ", map { defined()?$_:"NULL" } @$args);
  print " Args: [$args_str]\n";

  $sth->execute(@$args) 
    || confess( "failed to execute '$sql' with arguments [$args_str]" );

  return $self->{dbh}->{mysql_insertid};
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
    $e = $self->dosql_select( "SELECT * FROM $schema WHERE stop is null and id = ?", [$data{id}] );
    return $e->[0]->{value};
    
  } else {
    $e = $self->dosql_select( "SELECT * FROM $schema WHERE visual_id = ?", [$data{visual_id}] );
    return $e->[0]->{id};
  }
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
      $e = $self->dosql_select( "SELECT * FROM $schema WHERE stop is null and (lval = ? and rval = ?) or (rval = ? and lval = ?)", $data{lval}, $data{rval}, $data{rval}, $data{lval} );
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
    use Data::Dumper;
    print "*", Dumper( $e ), "\n";
    if( @$e ) {
      if(  $schema =~ /_R_/ || $schema =~ /_/ || grep { $schema eq $_ } 'MetaProperty', 'MetaEntity', 'MetaRelation', 'MetaInheritance' ) {
	my $row = shift @$e;
	my @fields;
	my @values;
	foreach my $key ( keys %$row ) {
	  my $magic = defined $row->{$key} ? " = " : " is ";

	  push( @fields, join($magic, $key, "?") );
	  push( @values, $row->{$key} );
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
1;
