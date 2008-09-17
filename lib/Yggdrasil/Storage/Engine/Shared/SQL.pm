package Yggdrasil::Storage::Engine::Shared::SQL;

use strict;
use warnings;

use base 'Yggdrasil::Storage';

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
    
    my (@sqlfields, @keys, @indexes);
    for my $fieldname (keys %$fields) {
	my $field = $fields->{$fieldname};
	my ($type, $null, $index) = ($field->{type}, $field->{null}, $field->{index});
	
	if ($null) {
	    $null = 'NULL';
	} else {
	    $null = 'NOT NULL';
	}

	push @keys, "KEY ($fieldname)" if $type eq 'SERIAL' && $self->_engine_requires_serial_as_key();

	$type = $self->_map_type( $type );
	push @indexes, [$fieldname, $type] if $index;

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
	push @indexes, ['stop', $datefield ];
	push @sqlfields, "check ( start <= stop )";
    }
    
    $sql .= join ",\n", @sqlfields;
    if (@keys) {
	$sql .= ",\n" . join ",\n", @keys;
    }
    $sql .= ");\n";

    $self->{logger}->debug( $sql );
    $self->_sql( $sql );
    
    for my $indexref (@indexes) {
	my $indexsql = $self->_create_index_sql($schema, $indexref->[0], $indexref->[1]);
	$self->{logger}->fatal( $indexsql );
	$self->_sql( $indexsql );
    }
    

    # Find a way to deal with return values from here, worked / didn't
    # would be nice.
    return 1;
}

# Create an index as per the default SQL method of doing so, this 
# should be overridden by engines with regards to fields that 
# require specific treatment, optimizing options or size limitations
# for indexes, but, at least this is a fallback.  This generic
# version does nothing with regards to the type at all.
sub _create_index_sql {
    my ($self, $schema, $field, $type) = @_;
    
    return "CREATE INDEX ${schema}_${field}_index ON $schema ($field)";
}

# Overload this in the engines if you require your serial fields to be
# keys.
sub _engine_requires_serial_as_key {
    my $self = shift;
    return 0;
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
    Yggdrasil::fatal( "The DB layer didn't return a statement handler! " . $dbh->errstr ) unless $sth;

    my $args_str = join(", ", map { defined()?$_:"NULL" } @attr);
    $self->{logger}->debug( "$sql -> Args: [$args_str]" );

    $sth->execute(@attr) || Yggdrasil::fatal( "Execute of the statement handler failed!", "[$sql] -> [$args_str]" );

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

    my($start,$stop);
    if( @schemalist % 2 ) {
	my $time = pop @schemalist;
	Yggdrasil::fatal "Expected HASH-ref" unless ref $time;

	($start,$stop) = ( $self->_convert_time($time->{start}),
			   $self->_convert_time($time->{stop}) );
    }

    # FIXME: This is not beautiful
    my $join = $schemalist[1]->{join};

    my (%fromtables, %temporals, @returns, @temporal_returns, 
	@wheres, @params, @requested_fields, $counter);
    
    $counter = 0;
    while (@schemalist) {	
	my ($schema, $queryref) = (shift @schemalist, shift @schemalist);
	Yggdrasil::fatal( "$queryref as given to _fetch isn't a reference" ) unless ref $queryref;

	my $where    = $queryref->{where};
	my $operator = $queryref->{operator} || '=';
	my $as       = $queryref->{as};

	my ($rf_tmp, $w_tmp, $p_tmp) = $self->_process_where($schema, $where, $operator);
	push( @requested_fields, @$rf_tmp );
	push( @wheres, @$w_tmp );
	push( @params, @$p_tmp );

	push @returns, $self->_process_return( $schema, $queryref->{return} );
	$fromtables{$schema} = $counter++;

	# $temporals{$schema} is to ensure we only treat every schema once.
	if (!$temporals{$schema} && $self->_schema_is_temporal( $schema )) {
	    $temporals{$schema}++;
	    my ($w_tmp, $tr_tmp) = $self->_process_temporal( $schema, $start, $stop, $join, $as );
	    push( @wheres, @$w_tmp );
	    push( @temporal_returns, @$tr_tmp );
	}
    }

    @returns = @requested_fields unless @returns;
    @returns = ('*') unless @returns;
    
    my $sql = 'SELECT ' . join(", ", @returns, @temporal_returns) . ' FROM ' . $self->_create_from( $join, \%fromtables );

    if (@wheres) {
	$sql .= ' WHERE ';
	$sql .= join(" and ", @wheres );
    }

    $self->{logger}->debug( $sql, " with [", join(", ", map { defined()?$_:"NULL" } @params), "]" );
    return $self->_sql( $sql, @params ); 
}

# Fetching a raw structure, with all fields.  Used by ydump and admin interfaces.
sub _raw_fetch {
    my $self     = shift;
    my $schema   = shift;
    my $queryref = shift;

    my $operator = $queryref->{operator} || '=';

    my( $rf, $where, $params ) = $self->_process_where($schema, $queryref->{where}, $operator);

    my @fieldlist;
    for my $field ($self->_fields_in_structure( $schema )) {
	if ($field eq 'start' || $field eq 'stop') {
	    $field = $self->_time_as_epoch( $field ) . " as $field";
	}
	push @fieldlist, $field;
    } 
    
    my $sql = "SELECT " . join(",", @fieldlist) .  " FROM " . $schema;
    $sql .= " WHERE " . join(" and ", @$where) if @$where;
    return $self->_sql( $sql, @$params );
}

# Creates a proper FROM statement, ensuring that joins happen properly
# if required.
sub _create_from {
    my $self = shift;
    my $isjoin = shift;
    my $tables = shift;

    if( $isjoin) {
	my @from;
	my $first = 1;
	for my $t (sort { $tables->{$a} <=> $tables->{$b} } keys %$tables ) {
	    if( $first ) {
		push @from, $t;
		$first = 0;
	    } else {
		unshift @from, "(";
		push( @from, "left join $t using(id)" );
		push( @from, ")" );
	    }
	}

	return join(" ", @from);
    } else {
	return join(", ", keys %$tables);
    }
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

    # Check if we already have the value
    my $aref = $self->fetch( $schema, { where => { %$fields } } );
    return 1 if @$aref;
    
    # Expire the old value
    if( defined $key && exists $fields->{$key} ) {
	$self->_expire( $schema, $key, $fields->{$key}); 
    }

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

# Store data in raw form into the structure given, the only exceptions
# are start and stop which are translated from epoch to the internal
# database format.  The structure is assumed to be capable of
# swallowing the data, and no checks are done (no expire, no time
# checking).  yrestore / admin interfaces are the only legitimate
# callers of this method.
sub _raw_store {
    my $self = shift;
    my $schema = shift;
    my %data = @_;

    my $fields = $data{fields};

    if ($fields->{start} || $fields->{stop}) {
	my ($sstart, $sstop) = ($self->_convert_time( delete $fields->{start} || 'NULL'), 
				$self->_convert_time( delete $fields->{stop}  || 'NULL'));
	
	$self->_sql( "INSERT INTO $schema (start,stop," . join(", ", keys %$fields) . ") VALUES ($sstart,$sstop, "
		     . join(", ", ('?') x keys %$fields) . ')', values %$fields);	
    } else {
	$self->_sql( "INSERT INTO $schema (" . join(", ", keys %$fields) . ") VALUES ( "
		     . join(", ", ('?') x keys %$fields) . ')', values %$fields);	
    }

    return 1;
}

# Expire a field with a given value that is current (stop is NULL).
sub _expire {
    my $self        = shift;
    my $schema      = shift;
    my $indexfield  = shift;
    my $index       = shift;

    return unless $self->_schema_is_temporal( $schema );

    my $nullopr = $self->_null_comparison_operator();
    $self->_sql( "UPDATE $schema SET stop = NOW() WHERE stop $nullopr NULL and $indexfield = ?", $index );    
}

# Generates a field / data based where clause, ensuring that the
# fields it works on are fully qualified and that the proper
# comparison operators (and value modifiers) are applied.  This only
# takes data into account, not the possible temporal bits of the where
# clause.  Look at _process_temporal (below) for that.
sub _process_where {
    my $self     = shift;
    my $schema   = shift;
    my $where    = shift;
    my $operator = shift;
    
    my( @requested_fields, @wheres, @params );
    for my $fieldname (keys %$where) {
	my $localoperator = $operator;
	my $value = $where->{$fieldname};
	
	$value = '%' . $value . '%' if $localoperator eq 'LIKE';
	my @fqfn = $self->_qualify( $schema, $fieldname );
    
	push @requested_fields, @fqfn;

	# If the value is a SCALAR reference, it means that it
	# should not be treated as real value (not to be bound to
	# a placeholder), but rather a reference to another table
	# and field. It should thus be put verbatim into the
	# generated SQL.
	if (! defined $value) {
	    $localoperator = $self->_null_comparison_operator() if $operator eq '=';
	    push @wheres, join " $localoperator ", $fqfn[0], 'NULL';	    
	} elsif ( ref $value eq "SCALAR" ) {
	    push @wheres, join " $localoperator ", $fqfn[0], $$value;
	} else {
	    push @wheres, join " $localoperator ", $fqfn[0], '?';
	    push @params, $value;
	}
    }

    return (\@requested_fields, \@wheres, \@params);
}

# Generate a temporally correct where clause the schema in question.
# The data to extract is built elsewhere, this just ensures we get a
# where clause that limits the "view" of the schema to the correct
# time slice.
sub _process_temporal {
    my ($self, $schema, $start, $stop, $join, $as) = @_;

    my (@wheres, @temporal_returns);

    my( $qstart ) = $self->_qualify($schema, 'start');
    my( $qstop )  = $self->_qualify($schema, 'stop');
    my $isnull = $self->_null_comparison_operator();

    if( defined $start ) {
	if (! defined $stop ) {
	    push @wheres, "( not $qstop <= $start or $qstop $isnull NULL )";
	} else {
	    if ($stop eq $start) {
		push @wheres, "$qstart <= $stop and ( $qstop > $start or $qstop $isnull NULL )";		
	    } else {
		push @wheres, "$qstart < $stop and ( $qstop > $start or $qstop $isnull NULL )";
	    }
	}
    } elsif( defined $stop ) {
	push @wheres, "$qstart <= $stop";
    } else {
	push @wheres, "$qstop $isnull NULL";
    }
    
    if( defined $start || defined $stop ) {
	my ($startt, $stopt) = ($self->_time_as_epoch( $qstart ),
				$self->_time_as_epoch( $qstop ));
	if( $join ) {
	    push( @temporal_returns, qq<$startt as "${as}_start">, qq<$stopt as "${as}_stop"> );
	} else {
	    push( @temporal_returns, $startt, $stopt );
	}
    }
    return (\@wheres, \@temporal_returns);
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
	Yggdrasil::fatal( "Unable to parse reference type, expected ARRAY or SCALAR" );
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
