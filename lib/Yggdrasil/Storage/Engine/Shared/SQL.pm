package Yggdrasil::Storage::Engine::Shared::SQL;

use strict;
use warnings;

use base 'Yggdrasil::Storage';

use Carp;

# Define a structure, it is assumed that the Storage layer has called
# _structure_exists() with the name of the structure to check its
# existance before _define is called.  If _define is called, the
# structure is expected to be non-existant.  For a definition of the
# call, see Yggdrasil::Storage::define().  At this point any table mappings are already done
sub _define {
    my $self   = shift;
    my $schema = shift;
    my %data   = @_;
    
    my $temporal = $data{temporal};
    my $fields   = $data{fields};

    my $sql = "CREATE TABLE $schema (\n";
    
    my (@sqlfields, @keys);
    for my $fieldname (keys %$fields) {
	my $field = $fields->{$fieldname};
	my ($type, $null) = ($field->{type}, $field->{null});

	if ($null) {
	    $null = 'NULL';
	} else {
	    $null = 'NOT NULL';
	}

	push @keys, "key ($fieldname)" if $type eq 'SERIAL';

	$type = $self->_map_type( $type );

	# FUGLY hack to ensure that id fields come first in the listings.
	if ($fieldname eq 'id') {
	    unshift @sqlfields, "$fieldname $type $null";
	} else {
	    push @sqlfields, "$fieldname $type $null";
	}
	
    }

    if ($temporal) {
	my $datefield = $self->_map_type( 'DATE' );
	push @sqlfields, "start $datefield NOT NULL";
	push @sqlfields, "stop  $datefield NULL";
	push @sqlfields, "index (stop)";
	push @sqlfields, "check ( start < stop )";
    }
    
    $sql .= join ",\n", @sqlfields;
    if (@keys) {
	$sql .= ",\n" . join ",\n", @keys;
    }
    $sql .= ");\n";

    $self->{logger}->debug( $sql );
    $self->_sql( $sql );

    # Find a way to deal with return values from here, worked / didn't
    # would be nice.
    return 1;
}

# Perform a prewritten statement that is not expected to return
# anything.  An important note here is that the table name is already
# given and assumed to be correct.  Any mapping has to be done before
# calling _sql.
sub _sql {
    my $self = shift;
    my $sql  = shift;
    my @attr = @_;
    
    my $dbh = $self->{dbh};
    my $sth = $dbh->prepare( $sql );
    confess( "no sth? " . $dbh->errstr ) unless $sth;

    my $args_str = join(", ", map { defined()?$_:"NULL" } @attr);
    $self->{logger}->debug( "$sql -> Args: [$args_str]" );
    
    $sth->execute(@attr) || confess( "execute??" );

    # FIX: if we do some DDL stuff, doing a fetch later on will make
    # DBD::mysql warn about calling fetch before execute. So if we do
    # DDL stuff, just return. Don't bother to fetch anything.
    # This should probably either be implemented as its own _ddlsql
    # or at least there should be some better way of figuring out
    # if we are doing DDL stuff.
    return if $sql =~ /^(CREATE|INSERT|UPDATE|DROP|TRUNCATE)/i;

    return $sth->fetchall_arrayref( {} );
}

# Fetch a list of values from a list of schemas.  All schemas are
# expected to exist, all fields are expected to exist.
sub _fetch {
    my $self = shift;
    my @schemalist = @_;
    $self->{logger}->warn( "_fetch( @_ )" );

    my (%fromtables, %temporals, @returns, @wheres, @params, @requested_fields);
    
    while (@schemalist) {	
	my ($schema, $queryref) = (shift @schemalist, shift @schemalist);
	confess( "$queryref isn't a reference" ) unless ref $queryref;
	
	my $where    = $queryref->{where};
	my $operator = $queryref->{operator} || '=';

	for my $fieldname (keys %$where) {
	    my $value = $where->{$fieldname};
	    # If the value we're looking for is undef, we're looking
	    # for NULL.  This might make us require using "is" as the
	    # operator for comparisons even if we were given '=', ask
	    # the engine for the appropriate NULL comparison operator.
	    unless (defined $value && $operator eq '=') {
		$operator = $self->_null_comparison_operator();
	    }


	    $value = '%' . $value . '%' if $operator eq 'LIKE';
	    my @fqfn = $self->_qualify( $schema, $fieldname );
    
	    push @requested_fields, @fqfn;

	    # If the value is a SCALAR reference, it means that it
	    # should not be treated as real value (not to be bound to
	    # a placeholder), but rather a reference to another table
	    # and field. It should thus be put verbatim into the
	    # generated SQL.
	    if( ref $value eq "SCALAR" ) {
		push @wheres, join " $operator ", $fqfn[0], $$value;
	    } else {
		push @wheres, join " $operator ", $fqfn[0], '?';
		push @params, $value;
	    }
	}
	
	push @returns, $self->_process_return( $schema, $queryref->{return} );

	$fromtables{$schema}++;

	if (!$temporals{$schema} && $self->_schema_is_temporal( $schema )) {
	    $temporals{$schema}++;
	    push @wheres, ($self->_qualify( $schema, 'stop' ))[0] . ' ' . $self->_null_comparison_operator() . " NULL";
	}
    }

    
    @returns = @requested_fields unless @returns;
    @returns = ('*') unless @returns;

    my $sql = 'SELECT ' . join(", ", @returns) . ' FROM ' . join(", ", keys %fromtables);

    if (@wheres) {
	$sql .= ' WHERE ';
	$sql .= join(" and ", @wheres );
    }
    
    $self->{logger}->debug( $sql, " with [", join(", ", @params), "]" );
    return $self->_sql( $sql, @params ); 
}

# Store a value in a table.  Insert new values as a new row unless the
# row already exists.  If the row is indeed new and the table is
# temporal remember to set start to NOW() and stop to NULL.  Lastly,
# if the table is temporal and there is a previous value, update the
# previous row, setting stop to NOW().
sub _store {
    my $self = shift;
    my $schema = shift;
    my %data = @_;

    my $key    = $data{key};
    my $fields = $data{fields};

    my $aref = $self->fetch( $schema, { where => { %$fields } } );
    return 1 if @$aref;

    # Expire the old value
    $self->_expire( $schema, $key, $fields->{$key}); 

    # Insert new value
    if ($self->_schema_is_temporal( $schema )) {
	$self->_sql( "INSERT INTO $schema (start, " . join(", ", keys %$fields) . ") VALUES (NOW(), "
		     . join(", ", ('?') x keys %$fields) . ')', values %$fields)
    } else {
	$self->_sql( "INSERT INTO $schema (" . join(", ", keys %$fields) . ") VALUES ( "
		     . join(", ", ('?') x keys %$fields) . ')', values %$fields)
    }
    return 1;
}

sub _expire {
    my $self        = shift;
    my $schema      = shift;
    my $indexfield  = shift;
    my $index       = shift;

    return unless $self->_schema_is_temporal( $schema );

    my $nullopr = $self->_null_comparison_operator();
    $self->_sql( "UPDATE $schema SET stop = NOW() WHERE stop $nullopr NULL and $indexfield = ?", $index );    
}

# Process return requests, accepting an arrayref or a scalar.
sub _process_return {
    my $self = shift;
    my $schema = shift;
    my $retrequest = shift;

    return unless $retrequest;
    
    if (ref $retrequest eq 'ARRAY') {
	return $self->_qualify( $schema, @$retrequest );
    } elsif (ref $retrequest) {
	confess "Unable to parse reference type, expected ARRAY or SCALAR";
    } else {
	return $self->_qualify( $schema, $retrequest );
    }
}

# Combine a schema and a field to a fully qualified name.  Accepts an
# array of fields or a single scalar.
sub _qualify {
    my $self = shift;
    my $schema = shift;
    my @fields = @_;

    my @fqfn = map { /\./ ? $_ : join(".", $schema, $_) } @fields;

    return @fqfn;
}

# Provides a default mapper for SQL engines.
sub get_default_mapper {
    my $self = shift;
    
    return $self->set_mapper( 'MD5' );
}


# Admin interface follows, it is expected that Storage has verified that these calls are valid.

sub _delete_structure {
    my $self   = shift;
    my $schema = shift;
    return unless $self->_structure_exists( $schema );
    
    $self->_sql( "DROP TABLE $schema" );
}

sub _truncate_structure {
    my $self   = shift;
    my $schema = shift;
    return unless $self->_structure_exists( $schema );

    $self->_sql( "TRUNCATE TABLE $schema" );
}

sub _dump_structure {
    my $self   = shift; 
    my $schema = shift;
    return unless $self->_structure_exists( $schema );
    
    my $dbh = $self->{dbh};
    return $dbh->selectall_arrayref( "select * from $schema" );
}

1;

__DATA__

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

  $data->{name} = $self->_map_table_name( $data->{name} ) if $data->{name};
  
  $sql =~ s/\[(.+?)\]/$data->{$1}/ge; #'"/

  $self->{logger}->debug( $sql );

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
  $self->{logger}->debug( "Args: [$args_str]" );

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
  $self->{logger}->debug( "Args: [$args_str]" );

  $sth->execute(@$args) 
    || confess( "failed to execute '$sql' with arguments [$args_str]" );

  return $self->_get_last_id( $sql );
}

sub exists {
    my $self      = shift;
    my $structure = shift;
    my $id        = shift;
    my $subkey    = shift || '';

    $self->{logger}->info( "SQL::Exists( $self, $structure, $id, $subkey)" );

    if ($structure =~ s/^Yggdrasil:://) {
	$self->{logger}->debug( $structure );
	if ($structure eq 'Relation' || $structure eq 'Entity') {
	    my $table = "Meta$structure";
	    my $field = lc $structure;
	    my $e = $self->dosql_select( "SELECT * FROM $table WHERE stop is null and $field = ?", [ $id ] );
	    $self->{logger}->debug( $e->[0]->{$field}?"HIT":"MISS" );
	    return $e->[0]->{$field};
	} elsif ($structure eq 'Property') {
	    my $e = $self->dosql_select( "SELECT * FROM MetaProperty WHERE stop is null and entity = ? and property = ?", [ $id, $subkey ] );
	    return $e->[0]->{property};
	}
    } else {
	$structure = $self->_map_table_name( $structure );
	my $e = $self->dosql_select( "SELECT * FROM $structure WHERE visual_id = ? ", [ $id ] );
	return $e->[0]->{id} || undef;
    }
    return undef;
}

sub search {
    my ($self, $entity, $property, $value) = @_;

    # Check if the entity exists.
    return undef unless $self->exists( 'Yggdrasil::Entity', $entity );

    # Check if the property exists.
    return undef unless $self->exists( 'Yggdrasil::Property', $entity, $property );

    my $et = $self->_map_table_name( $entity );
    my $pt = $self->_map_table_name( $entity . '_' . $property );

    my $sql = "SELECT visual_id, ${et}.id FROM $et, $pt WHERE stop is null and value LIKE '%" . $value . "%' and ${pt}.id = ${et}.id";
    # Actually search.
    print "$sql\n";
    my $e = $self->dosql_select( $sql );
    
    return unless @$e;

    my %ids;
    for my $row (@$e) {	
	$ids{$row->{visual_id}} = $row->{id};
   }
    
    return \%ids;
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

      my $table = $self->_map_table_name( $schema );
      
      $e = $self->dosql_select( "SELECT * FROM $table WHERE stop is null and id = ?", [$data{id}] );
      return $e->[0]->{value};
    
  } else {
      my $table = $self->_map_table_name( $schema );
      $e = $self->dosql_select( "SELECT * FROM $table WHERE visual_id = ?", [$data{visual_id}] );
      return $e->[0]->{id};
  }
}

sub expire {
  my $self = shift;
  my $schema = shift;
  my %data = @_;

  my $table = $self->_map_table_name( $schema );
  
  $self->dosql_update( "UPDATE $table SET stop = NOW() WHERE stop is null and lval = ? and rval = ?", [$data{lval}, $data{rval}] );
}


sub update {
    my $self = shift;
    my $schema = shift;
    my %data = @_;
    my $table = $self->_map_table_name( $schema );

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
	$e = $self->dosql_select( "SELECT * FROM $table WHERE stop is null and lval = ? and rval = ?", [ $data{lval}, $data{rval} ] );
	my $h = $e->[0];
	return $h->{id} if $h->{id};
    }
    # Do we have an active property value that's different from the one we're trying to insert.
    elsif( $schema =~ /_/ ) {
	$e = $self->dosql_select( "SELECT * FROM $table WHERE stop is null and id = ? and value != ?", [$data{id}, $data{value}] );
      
	# Are we trying to insert the exact same value for the same property again?
	# If so, do nothing and return the ID of the previous entry.
	if (! @$e) {
	    my $old = $self->dosql_select( "SELECT * FROM $table WHERE stop is null and id = ? and value = ?", [$data{id}, $data{value}] );
	    return $old->[0]->{id} if $old->[0]->{id};
	}
    }
   else {
       $e = $self->dosql_select( "SELECT * FROM $table WHERE visual_id = ?", [$data{visual_id}] );
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
	
	$self->dosql_update( "UPDATE $table SET stop = NOW() WHERE $where", \@values );
      } else {
	$self->{logger}->error( "Why here?" );
	return $e->[0]->{id};
      }
    }

    # --- 2. Insert
    my $columns  = join(", ", keys %data);
    my $question = join(", ", ("?") x keys %data);

      if( $schema =~ /_R_/ || $schema =~ /_/ || grep { $schema eq $_ } 'MetaProperty', 'MetaEntity', 'MetaRelation', 'MetaInheritance'   ) {
	return $self->dosql_update( "INSERT INTO $table($columns, start) VALUES($question, NOW())", [values %data] );
      } else {
	return $self->dosql_update( "INSERT INTO $table($columns) VALUES($question)", [values %data] );
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

