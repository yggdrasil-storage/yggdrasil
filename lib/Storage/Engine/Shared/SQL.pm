package Storage::Engine::Shared::SQL;

use strict;
use warnings;

use base 'Storage';

# use Yggdrasil::Debug qw|debug_if debug_level|;

# Define a structure, it is assumed that the Storage layer has called
# _structure_exists() with the name of the structure to check its
# existance before _define is called.  If _define is called, the
# structure is expected to be non-existant.  For a definition of the
# call, see Storage::define().  At this point any table mappings are already done
sub _define {
    my $self   = shift;
    my $schema = shift;
    my %data   = @_;
    
    my $temporal = $data{temporal};
    my $fields   = $data{fields};
    my $hints    = $data{hints};

    my $sql = "CREATE TABLE $schema (\n";
 
    my (@sqlfields, @indexes, %keys);
    for my $fieldname (keys %$fields) {
	my $field = $fields->{$fieldname};
	my ($type, $null, $index, $default) = ($field->{type}, $field->{null}, $field->{index}, $field->{default});
	
	$null = $null ? 'NULL' : 'NOT NULL';
	$default = defined $default ? "DEFAULT $default" : '';
	
	$keys{$fieldname}++ if $type eq 'SERIAL' && $self->_engine_requires_serial_as_key();

	$type = $self->_map_type( $type );
	push @indexes, $fieldname if $index;

	# FUGLY hack to ensure that id fields come first in the listings.
	if ($fieldname eq 'id') {
	    unshift @sqlfields, "$fieldname $type $null $default";
	} else {
	    push @sqlfields, "$fieldname $type $null $default";
	}
    }

    for my $fieldname (keys %$hints) {
	my $field = $hints->{$fieldname};
	$keys{$fieldname}++ if $field->{key};

	push @indexes, $fieldname if $field->{index}; # && (keys %keys > 1);
	
	# FIXME: Foregin keys isn't supported as of yet.  The issue is
	# MetaEntity and its friends requiring the key to be both ID
	# and START, but we can't make the foreign key contain both
	# values.  Also, time we need to be able to reuse ID (which is
	# a SERIAL field...) for rename et al.  This is bad[tm].  For now,
	# disable foreign key generation.
	
	# push @sqlfields, $self->_create_foreign_key( $field->{foreign}, $fieldname ) if $field->{foreign};
    }

    $sql .= join ",\n", @sqlfields;
    $sql .= ",\nPRIMARY KEY (" . join( ", ", keys %keys ) . ")" if %keys &&
	  $self->_engine_supports_primary_keys();
    $sql .= ") ";
    $sql .= $self->_engine_post_create_details();
    $sql .= ";\n";
    
#    $self->{logger}->debug( $sql );
    $self->_sql( $sql );

    for my $field (@indexes) {
	my $indexsql = $self->_create_index_sql($schema, $field );
	$self->{logger}->fatal( $indexsql );
	$self->_sql( $indexsql );
    }
    
    # Find a way to deal with return values from here, worked / didn't
    # would be nice.
    return 1;
}

# Does the engine support primary keys, and does that support include
# multiple fields to be used as composite keys?  If you can't support
# this, override it in the engine class.  SQLite for needs this.
sub _engine_supports_primary_keys {
    return 1;
}

# If the engine requires something extra to be added to the end of the
# CREATE TABLE ( ... ) statement, you can overload this method.
# Typically used to make mysql add things like "ENGINE=InnoDB".
sub _engine_post_create_details {
    return "";
}

# Create an index as per the default SQL method of doing so, this 
# should be overridden by engines with regards to fields that 
# require specific treatment, optimizing options or size limitations
# for indexes, but, at least this is a fallback.  This generic
# version does nothing with regards to the type at all.
sub _create_index_sql {
    my ($self, $schema, $field) = @_;
    
    return "CREATE INDEX ${schema}_${field}_index ON $schema ($field)";
}

sub _create_foreign_key {
    my ($self, $target, $field) = @_;

    return "FOREIGN KEY ($field) REFERENCES $target(id)";
}

# Overload this in the engines if you require your serial fields to be
# keys.
sub _engine_requires_serial_as_key {
    my $self = shift;
    return 0;
}

sub _last_insert_id {
    my $self = shift;
    my $table = shift;

    my $dbh = $self->{dbh};
    return $dbh->last_insert_id( undef, undef, $table, undef );
}

sub _apply_filter {
    my $self   = shift;
    my $filter = shift;
    my $field  = shift;

    my @parts = split m/\./, $field;

    if( uc($filter) eq "MAX" ) {
	return "MAX($field) AS max_" . $parts[-1];
    } elsif( uc($filter) eq "MIN" ) {
	return "MIN($field) AS min_" . $parts[-1];
    } else {
	Yggdrasil::fatal( "No such filter as $filter" );
    }
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

    my $status = $self->get_status();
    
    unless ($sth) {
	$status->set( 500, 'The DB layer didn\'t return a statement handler' );
	return;
    }

    # Log + debugging.
    my $args_str = join(", ", map { defined()?$_:"NULL" } @attr);    
#    $self->{logger}->debug( "$sql -> Args: [$args_str]" );
#    debug_if( 5, "SQL: $sql -> Args: [$args_str]" );

    # Transaction information.
    my $sqlinline = $sql;
    for my $attr ( @attr ) {
	my $value = defined $attr ? $attr : "NULL";
	$sqlinline =~ s/\?/"'$value'"/e;
    }
    $self->{transaction}->engine( $sqlinline );
    print "$sqlinline\n" if $self->{_debug}->{protocol};
    unless ($sth->execute(@attr)) {
	$status->set( 500, "Execute of the statement handler failed!", "[$sql] -> [$args_str]" );
	return;
    }
    
    # FIX: if we do some DDL stuff, doing a fetch later on will make
    # DBD::mysql warn about calling fetch before execute. So if we do
    # DDL stuff, just return. Don't bother to fetch anything.
    # This should probably either be implemented as its own _ddlsql
    # or at least there should be some better way of figuring out
    # if we are doing DDL stuff.
    if ($sql =~ /^(CREATE|INSERT|UPDATE|DROP|TRUNCATE)/i) {
	$status->set( 201 );
	return 1;
    }

    return $sth->fetchall_arrayref( {} );
}

# Fetch a list of values from a list of schemas.  All schemas are
# expected to exist, all fields are expected to exist.
sub _fetch {
    my $self = shift;
    my @schemalist = @_;

    my($start,$stop);
    my $status = $self->get_status();
    if( @schemalist % 2 ) {
	my $time = pop @schemalist;

	unless (ref $time) {
	    $status->set( 500, "Time slice given to _fetch wasn't a hash reference" );
	    return undef;
	}

# Removed, we're working with ticks.	
#	($start,$stop) = ( $self->_convert_time($time->{start}),
#			   $self->_convert_time($time->{stop}) );

	($start,$stop) = ( $time->{start}, $time->{stop} );
    }

    my (%fromtables, %temporals, @returns, @temporal_returns, 
	@wheres, @params, @requested_fields, $counter);
    
    $counter = 0;
    while (@schemalist) {	
	my ($schema, $queryref) = (shift @schemalist, shift @schemalist);
	unless (ref $queryref) {
	    $status->set( 500, "The query reference given to _fetch wasn't a hash reference" );
	    return undef;
	}

	my $where    = $queryref->{where};
	my $operator = $queryref->{operator} || '=';
	my $as       = $queryref->{as};
	my $bind     = $queryref->{bind} || 'and';
	my $alias    = $queryref->{alias} || $schema;
	my $filter   = $queryref->{filter};

	my $real_schema = $schema;
	$schema = $alias;
	
	my ($rf_tmp, $w_tmp, $p_tmp) = $self->_process_where($schema, $where, $operator);
	my $where_sql;
	if( @$w_tmp ) {
	    $where_sql = "(" . join( " ".$bind." ", @$w_tmp ) . ")";
	}

	push( @requested_fields, @$rf_tmp );
	push( @wheres, $where_sql ) if $where_sql;
	push( @params, @$p_tmp );

	push @returns, $self->_process_return( $schema, $queryref->{return} );
	$fromtables{$schema} = [ $counter++, $real_schema, $queryref->{join} ];

	# $temporals{$schema} is to ensure we only treat every schema once.
	if (!$temporals{$schema} && $self->_schema_is_temporal( $real_schema )) {
	    $temporals{$schema}++;
	    my ($w_tmp, $tr_tmp) = $self->_process_temporal( $schema, $start, $stop, $as );
	    push( @wheres, @$w_tmp );
	    push( @temporal_returns, @$tr_tmp );
	}

	if( $filter ) {
	    $filter = [$filter] unless ref $filter;
	    for( my $i=0; $i<@$filter; $i++ ) {
		$returns[$i] = $self->_apply_filter( $filter->[$i], $returns[$i] );
	    }
	}
    }

    @returns = @requested_fields unless @returns;
    @returns = ('*') unless @returns;
    
    # This call destroys %fromtables
    my $sql = 'SELECT DISTINCT ' . join(", ", @returns, @temporal_returns) . ' FROM ' . $self->_create_from( \%fromtables );

    if (@wheres) {
	$sql .= ' WHERE ';
	$sql .= join(" and ", @wheres );
    }

#    my ($package, $filename, $line, $subroutine, $hasargs,
#     $wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(2);

#    if ($subroutine =~ /_store/) {
#	print STDERR "$sql with [" . join(", ", map { defined()?$_:"NULL" } @params) . "]\n";
#    }  
    
#    $self->{logger}->debug( $sql, " with [", join(", ", map { defined()?$_:"NULL" } @params), "]" );
    $status->set( 200 );
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
#	if ($field eq 'start' || $field eq 'stop') {
#	    $field = $self->_time_as_epoch( $field ) . " as $field";
#	}
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
    my $tables = shift;

    my @joined = grep { my $struct = $tables->{$_}; 
			$struct->[2] && $struct->[2] eq "left" } keys %$tables;

    my $leftjoins;
    if( @joined ) {
	my @from;
	my $first = 1;
	for my $t ( @joined ) {
	    my $alias = $t;
	    my $real_t  = $tables->{$t}->[1];
	    my $tablename = $real_t;
	    if( $alias ne $real_t ) {
		$tablename = join(" ", $real_t, $alias );
	    }

	    if( $first ) {
		push @from, $tablename;
		$first = 0;
	    } else {
		unshift @from, "(";
		push( @from, "left join $tablename using(id)" );
		push( @from, ")" );
	    }

	    delete $tables->{$t};
	}

	$leftjoins = join(" ", @from);
    } 

    my @from;
    foreach my $t ( keys %$tables ) {
	my $alias = $t;
	my $real_t = $tables->{$t}->[1];
	my $tablename = $real_t;
	if( $alias ne $real_t ) {
	    $tablename = join(" ", $real_t, $alias );
	}
	push( @from, $tablename );
    }

    my $joins = join(", ", @from);

    $joins .= ", $leftjoins" if $leftjoins;

    return $joins;
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
    my $fields = $data{fields} || {};
    my $tick   = $data{tick};

    # If the schema is temporal, we need to insert the current tick
    # into 'start' - so add 
    my( @tick_key, @tick_val );
    if( $self->_schema_is_temporal($schema) ) {
	@tick_val = ($tick);
	@tick_key = ('start');
    }

    # The fields we want to insert into
    my $dbfields = join(", ", keys %$fields, @tick_key);

    # how many '?' to generate
    # need to test to avoid adding with undef
    my $num = keys %$fields;
    $num = $num ? $num + @tick_val : @tick_val;
    my $placeholders = join(", ", ('?') x $num );

    # Execute the SQL and fetch the generated id (if any)
    my $sql = "INSERT INTO $schema ($dbfields) VALUES($placeholders)";
    $self->_sql( $sql, values %$fields, @tick_val );
    my $r = $self->_last_insert_id( $schema );

    unless( $r ) {
	# FIX: can we safely assume "id"? No we can not.
	$r = $fields->{id};
    }

    my $status = $self->get_status();
    $status->set( 200, "Value(s) set" );
    return $r;
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
#	my ($sstart, $sstop) = ($self->_convert_time( delete $fields->{start} || 'NULL'), 
#				$self->_convert_time( delete $fields->{stop}  || 'NULL'));

	my ($sstart, $sstop) = (delete $fields->{start} || 'NULL',
				delete $fields->{stop}  || 'NULL');

	
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
    my $self   = shift;
    my $schema = shift;
    my $tick   = shift;
    my %params = @_;

    return unless $self->_schema_is_temporal( $schema );

    my $status = $self->get_status();
    my $nullopr = $self->_null_comparison_operator();
	
    my @sets;

    for my $key (keys %params) {
	push @sets, "$key = ?";
	unless (defined $params{$key}) {
	    $status->set( 400, "Expire for $schema at tick $tick, but $key is not defined" );
	    return;	    
	}
    }
    my $keys = join " and ", @sets;

    $status->set( 200 );
    $self->_sql( "UPDATE $schema SET stop = ? WHERE stop $nullopr NULL and $keys", $tick, values %params );
}

# Generates a field / data based where clause, ensuring that the
# fields it works on are fully qualified and that the proper
# comparison operators (and value modifiers) are applied.  This only
# takes data into account, not the possible temporal bits of the where
# clause.  Look at _process_temporal (below) for that.
sub _process_where {
    my $self     = shift;
    my $schema   = shift;
    my $where    = shift || [];
    my $operator = shift;

    my $opcount = 0;
    my( @requested_fields, @wheres, @params );
    for( my $i=0; $i < @$where; $i += 2 ) {
	my $localoperator;

	if (ref $operator eq 'ARRAY') {
	    $localoperator = $$operator[$opcount++];
	} else {
	    $localoperator = $operator;
	}

	my $fieldname = $where->[$i];
	my $value = $where->[$i+1];
	
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
	} elsif ( ref $value eq "ARRAY" ) {
	    my $placeholders = join( ", ", ("?")x@$value );
	    push @wheres, "$fqfn[0] IN (" . $placeholders . ")";
	    push @params, @$value;
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
    my ($self, $schema, $start, $stop, $as) = @_;

    my (@wheres, @temporal_returns);

    my( $qstart ) = $self->_qualify($schema, 'start');
    my( $qstop )  = $self->_qualify($schema, 'stop');
    my $isnull = $self->_null_comparison_operator();

    if( defined $start ) {
	if (! defined $stop ) {
	    push @wheres, "( not $qstop <= $start or $qstop $isnull NULL )";
	} else {
	    my $op = $stop == $start?'<=':'<';
	    push @wheres, "($qstart $isnull NULL or $qstart $op $stop) and ( $qstop > $start or $qstop $isnull NULL )";
	}
    } elsif( defined $stop ) {
	push @wheres, "$qstart <= $stop";
    } else {
	push @wheres, "$qstop $isnull NULL";
    }
    
    if( defined $start || defined $stop ) {
#	my ($startt, $stopt) = ($self->_time_as_epoch( $qstart ),
#				$self->_time_as_epoch( $qstop ));

	my ($startt, $stopt) = ($qstart, $qstop);
	if( $as ) {
	    push( @temporal_returns, qq<$startt as "${as}_start">, qq<$stopt as "${as}_stop"> );
	} else {
	    push( @temporal_returns, qq<$startt as "start">, qq<$stopt as "stop"> );
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
	my $status = $self->get_status();
	$status->set( 500, "Unable to parse the reference type given to _process_return, expected ARRAY or SCALAR" );
	return undef;
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
