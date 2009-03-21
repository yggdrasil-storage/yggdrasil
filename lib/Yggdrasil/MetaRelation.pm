package Yggdrasil::MetaRelation;

use strict;
use warnings;

use base qw(Yggdrasil::Object);

sub define {
    my $class = shift;
    my $self =  $class->SUPER::new(@_);
  
    my $storage = $self->{yggdrasil}->{storage};
    
    $storage->define( "Relations", 
		      fields   => { 
				   id   => { type => 'INTEGER' },
				   lval => { type => "INTEGER" },
				   rval => { type => "INTEGER" },
				  },
		      temporal => 1,
		      nomap    => 1,
		      hints    => {
				   id   => { index => 1, foreign => 'MetaRelation' },
				   lval => { foreign => 'Entities' },
				   rval => { foreign => 'Entities' },
				  },
		    );
    
    
    $storage->define( "MetaRelation",
		      fields   => { id          => { type => "SERIAL" },
				    requirement => { type => "VARCHAR(255)", null => 1 },
				    lval        => { type => "INTEGER",      null => 0 },
				    rval        => { type => "INTEGER",      null => 0 },
				    label       => { type => 'VARCHAR(255)', null => 0 },
				    l2r         => { type => 'VARCHAR(255)', null => 1 },
				    r2l         => { type => 'VARCHAR(255)', null => 1 },
				  },
		      temporal => 1,
		      nomap    => 1,
		      hints    => {
				   lval => { index => 1, foreign => 'MetaEntity' },
				   rval => { index => 1, foreign => 'MetaEntity' },
				  }
		    );
}

sub add {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    my %params = @_;

    my $lval  = $params{lval};
    my $rval  = $params{rval};
    my $label = $params{label};
  
    $self->{yggdrasil}->{storage}->store( "MetaRelation",
					  key    => "label",
					  fields => {
						   label => $label,
						     lval  => $lval,
						     rval  => $rval,
						     l2r   => $params{l2r},
						     r2l   => $params{r2l},
						   
						     requirement => $params{requirement},				      
						    });
  
    my $ref = $self->{yggdrasil}->{storage}->fetch( 'MetaRelation', { return => 'id', where => [ label => $label ]});
    return $ref->[0]->{id};
}

sub _admin_dump {
    my $self = shift;

    return $self->{storage}->raw_fetch( "MetaRelation" );
}

sub _admin_restore {
    my $self = shift;
    my $data = shift;

    $self->{storage}->raw_store( "MetaRelation", fields => $data );

    my $id = $self->{storage}->raw_fetch( MetaRelation =>
					  { return => "id",
					    where  => [ %$data ] } );

    return $id->[0]->{id};
}


1;
