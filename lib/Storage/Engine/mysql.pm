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

1;
