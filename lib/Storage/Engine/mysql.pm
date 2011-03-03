package Storage::Engine::mysql;

use strict;
use warnings;

use base 'Storage::Engine::Shared::SQL';

use DBI;

our $VERSION = '0.1.5';

our %TYPEMAP = (
		DATE     => 'DATETIME',
		BINARY   => 'MEDIUMBLOB', # 2^24, 16MiB.
                PASSWORD => 'VARCHAR(255)',
	       );

sub new {
  my $class = shift;
  my $self  = {};
  my %data  = @_;

  bless $self, $class;

  my $status = $self->get_status();

  my @missing;
  for my $param (qw|host user password db|) {
      push @missing, $param unless $data{$param};
  }

  if (@missing) {
      $status->set( 404, 'Missing database parameter(s): ' . join ", ", @missing );
      return undef;
  }

  $data{port} ||= 3306;
  
  $self->{dbh} = DBI->connect( "DBI:mysql:database=$data{db};host=$data{host};port=$data{port}", $data{user}, $data{password}, { RaiseError => 1 } );

  $self->{port} = $data{port};
  $self->{host} = $data{host};
  $self->{dbuser} = $data{user};
  $self->{db} = $data{db};

  return $self;
}

sub engine_version {
    return $VERSION;
}

sub maxid {
    return 18446744073709551614;
}

sub engine_type {
    my $self = shift;
    return $self->_engine();
}

sub info {
    my $self = shift;

    my $engine = $self->_engine();
    return sprintf "$engine storage backend, connected to %s:%s as the user '%s' to the database '%s'.",
      $self->{host}, $self->{port}, $self->{dbuser}, $self->{db};
}

sub size {
    my $self = shift;
    my $structure = shift;

    if ($structure) {
	if ($self->_structure_exists( $structure )) {
	    my $ref = $self->_sql("SHOW table status where Name = ?", $structure);
	    return $ref->[0]->{Data_length} + $ref->[0]->{Index_length};
	} else {
	    return undef;
	}
    } else {
	my $ref = $self->_sql("SELECT Sum( data_length + index_length ) as size FROM information_schema.tables where table_schema = ?", $self->{db} );
	return $ref->[0]->{size};
    }
}

sub storage_is_empty {
    my $self = shift;
    my $prefix = $self->prefix();
    
    for my $struct ($self->_list_structures()) {
	return 0 if $struct !~ /^$prefix/;
    }
    return 1;
}

sub _structure_exists {
    my $self = shift;
    my $structure = shift;

    for my $table ( $self->_list_structures( $structure ) ) {
	return $structure if $table eq $structure;
    }    
    return 0;
}

sub _list_structures {
    my $self = shift;
    my $structure = shift;

    my $string = "SHOW TABLES";
    $string .= " LIKE '%" . $structure . "%'" if $structure;
    
    my( $e ) = $self->_sql( $string );

    my @tables;
    for my $row ( @$e ) {
	for my $table ( values %$row ) {
	    push @tables, $table;
	}
    }
    return @tables;
}

sub _fields_in_structure {
    my $self = shift;
    my $structure = shift;

    my ( $e ) = $self->_sql("SHOW FIELDS FROM $structure");

    return map { $_->{Field} } @$e;
}

sub _map_type {
    my $self = shift;
    my $type = shift;

    return $TYPEMAP{$type} || $type;
}

sub _null_comparison_operator {
    my $self = shift;
    return 'is';
}

sub _engine_requires_serial_as_key {
    my $self = shift;
    return 1;
}

# FIXME, some way of telling mysql.pm which engine to use might be
# useful for some people.
sub _engine_post_create_details {
    return "ENGINE=InnoDB";
}

sub _convert_time {
    my $self = shift;
    my $time = shift;

    return $time unless defined $time;

    if( $self->_isepoch($time) ) {
	return "FROM_UNIXTIME($time)";
    }
    return $time;
}

sub _time_as_epoch {
    my $self = shift;
    my $time = shift;

    return "UNIX_TIMESTAMP($time)";
}

sub _create_index_sql {
    my ($self, $schema, $field, $fielddata) = @_;

    # This is a storage type
    my $type = $fielddata->{type};
    
    if ($type eq 'TEXT' || $type eq 'BINARY') {
	return "CREATE INDEX ${schema}_${field}_index ON $schema ($field(255))";
    } elsif ($type eq 'SET') {	
	return undef;
    } else {
	return "CREATE INDEX ${schema}_${field}_index ON $schema ($field)";
    }
}

sub _extra_debugging_enable {
    my $self = shift;
    my $sql  = shift;
    my @attr = @_;
    
    my $dbh = $self->{dbh};
    return unless $self->debug( 'protocol' );
    
    my $dsth = $dbh->prepare( "explain $sql" );
    $dsth->execute( @attr );

    my $aref = $dsth->fetchall_arrayref( {} );

    my @keys   = qw|id select_type table type key key_len ref rows Extra possible_keys|;
    my $format = "%2s %-12s %-25s %-6s %-35s %-8s %-26s %-8s %-30s %s\n";
    
    open( my $fh, '>>', 'storage.debug.protocol.log' );
    my $sqlinline = $sql;
    for my $attr ( @attr ) {
	my $value = defined $attr ? $attr : "NULL";
	$sqlinline =~ s/\?/"'$value'"/e;
    }
    print $fh "{{{\n$sqlinline\n\n";
    printf $fh $format, @keys;
    
    for my $href (@$aref) {
	my %hash = %$href;
	printf $fh $format, map { defined $_?$_:'NULL' } @hash{@keys};
    }
    close $fh;
    
    $dbh->do( 'set profiling=1' );
}

sub _extra_debugging_disable {
    my $self = shift;
    return unless $self->debug( 'protocol' );

    my $dbh  = $self->{dbh};
    my $dsth = $dbh->prepare( "show profile" );
    $dsth->execute();

    my $aref = $dsth->fetchall_arrayref( {} );

    my @keys   = qw|Duration Status|;
    my $format = "%9s : %s\n";
    
    open( my $fh, '>>', 'storage.debug.protocol.log' );
    printf $fh "\n$format", @keys;

    my $total = 0;
    for my $href (@$aref) {
	my %hash = %$href;
	printf $fh $format, @hash{@keys};
	$total += $href->{Duration};
    }
    printf $fh "%9.6f : %s\n", $total, 'Total';
    
    print $fh "\n}}}\n\n";
    close $fh;
    
    $self->{dbh}->do( 'set profiling=0' );
}

1;
