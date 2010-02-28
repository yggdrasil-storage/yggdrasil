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
				   lval => { foreign => 'Instances' },
				   rval => { foreign => 'Instances' },
				  },
		      auth => {
			       # Create a new link.
			       create => [
					  MetaEntity => { entity => '__ENTITY1__', alias => 'E1' },
  					  'MetaEntity:Auth' => { 
								id => \qq<E1.id>,
								r  => 1,
							       },
					  MetaEntity => { entity => '__ENTITY2__', alias => 'E2' },
  					  'MetaEntity:Auth' => { 
								id => \qq<E2.id>,
								r  => 1,
							       },
					  Instances => { visual_id => '__INSTANCE1__', alias => 'I1' },
					  'Instances:Auth' => {
							       id  => \qq<I1.id>,
							       'm' => 1,
							      },
					  Instances => { visual_id => '__INSTANCE2__', alias => 'I2' },
					  'Instances:Auth' => {
							       id  => \qq<I2.id>,
							       'm' => 1,
							      },
					  MetaRelation => { label => '__RELATION__' },
					  'MetaRelation:Auth' => { 
								  id => \qq<MetaRelation.label>,
								  w  => 1,
								 },
					 ],
			       # Expire a link.  Oddly similar to create (above).
			       expire => [
					  MetaEntity => { entity => '__ENTITY1__', alias => 'E1' },
  					  'MetaEntity:Auth' => { 
								id => \qq<E1.id>,
								r  => 1,
							       },
					  MetaEntity => { entity => '__ENTITY2__', alias => 'E2' },
  					  'MetaEntity:Auth' => { 
								id => \qq<E2.id>,
								r  => 1,
							       },
					  Instances => { visual_id => '__INSTANCE1__', alias => 'I1' },
					  'Instances:Auth' => {
							       id  => \qq<I1.id>,
							       'm' => 1,
							      },
					  Instances => { visual_id => '__INSTANCE2__', alias => 'I2' },
					  'Instances:Auth' => {
							       id  => \qq<I2.id>,
							       'm' => 1,
							      },
					  MetaRelation => { label => '__RELATION__' },
					  'MetaRelation:Auth' => { 
								  id => \qq<MetaRelation.label>,
								  w  => 1,
								 },
					 ],
			       # Read a link, ie, follow it.
			       fetch => [
					 Relations => { id => '__SELF__' },
					 ':Auth'     => {
							 id => \qq<Relations.id>,
							 r  => 1,
							},
					],
			       # Update, NOT allowed.
			       update => undef,
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
				  },
		      auth => {
			       # To create a Relation between two entities one must have
			       # permissions to modify both entites.  The order of E1 / E2 is
			       # irrelevant.
			       create => [					  
					  MetaEntity => { entity => '__ENTITY1__', alias => 'E1' },
					  'MetaEntity:Auth' => {
								id  => \qq<E1.id>,
								'm' => 1,
							       },
					  MetaEntity => { entity => '__ENTITY2__', alias => 'E2' },
					  'MetaEntity:Auth' => {
								id  => \qq<E2.id>,
								'm' => 1,
							       },
					 ],
			       # To fetch a relation, one must be able to read it.
			       fetch => [
					 MetaRelation => { label => '__SELF__' },
					 ':Auth'        => { 
							    id => \qq<MetaRelation.label>,
							    r  => 1,
							   },
					],
			       # To expire / delete a relation, modify both entities and the
			       # relation itself.
			       expire => [
					  MetaEntity => { entity => '__ENTITY1__', alias => 'E1' },
					  'MetaEntity:Auth' => {
								id  => \qq<E1.id>,
								'm' => 1,
							       },
					  MetaEntity => { entity => '__ENTITY2__', alias => 'E2' },
					  'MetaEntity:Auth' => {
								id  => \qq<E2.id>,
								'm' => 1,
							       },
					  MetaRelation => { label => '__SELF__' },
					  ':Auth'        => { 
							     id  => \qq<MetaRelation.label>,
							     'm' => 1,
							    },
					 ],
			       # re-lable.
			       update => [
					  MetaRelation => { label => '__SELF__' },
					  ':Auth'        => { 
							     id  => \qq<MetaRelation.label>,
							     'm' => 1,
							    },
					 ],
			      },
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
