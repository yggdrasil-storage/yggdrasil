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

    # Check if we already have the value
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
