package Yggdrasil::MetaRelation;

use strict;
use warnings;

use base qw(Yggdrasil::Object);

sub define {
    my $class = shift;
    my $self =  $class->SUPER::new(@_);
  
    my $storage = $self->{yggdrasil}->{storage};
    
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
		      authschema => 1,
		      auth => {
			       # To create a Relation between two entities one must have
			       # permissions to modify both entites.  The order of E1 / E2 is
			       # irrelevant.
			       create => [					  
					  'MetaEntity:Auth' => {
								where => [
									  id  => \q<lval>,
									  'm' => 1,
									 ],
							       },
					  'MetaEntity:Auth' => {
								where => [
									  id  => \qq<rval>,
									  'm' => 1,
									 ],
							       },
					 ],
			       # To fetch a relation, one must be able to read it.
			       fetch => [
					 ':Auth' => {
						     where => [
							       id => \qq<MetaRelation.id>,
							       r  => 1,
							      ],
						    },
					],
			       # To expire / delete a relation, modify both entities and the
			       # relation itself.
			       expire => [
					  'MetaEntity:Auth' => {
								where => [
									  id  => \qq<MetaRelation.lval>,
									  'm' => 1,
									 ],
							       },
					  'MetaEntity:Auth' => {
								where => [
									  id  => \qq<MetaRelation.rval>,
									  'm' => 1,
									 ],
							       },
					  ':Auth' => {
						      where => [
								id  => \qq<MetaRelation.id>,
								'm' => 1,
							       ],
						     },
					 ],
			       # re-lable.
			       update => [
					  ':Auth' => { 
						      where => [
								id  => \qq<MetaRelation.id>,
								'm' => 1,
							       ],
						     },
					 ],
			      },
		    );
        
    $storage->define( "Relations", 
		      fields   => {
				   id => { type => 'SERIAL' },
				   relationid => { type => 'INTEGER' },
				   lval => { type => "INTEGER" },
				   rval => { type => "INTEGER" },
				  },
		      temporal => 1,
		      nomap    => 1,
		      hints    => {
				   relationid => { index => 1, foreign => 'MetaRelation', key => 1 },
				   lval => { index => 1, foreign => 'Instances', key => 1 },
				   rval => { index => 1, foreign => 'Instances', key => 1 },
				  },
		      authschema => 1,
		      auth => {
			       # Create a new link.
			       create => [
					  'Instances:Auth' => {
							       where => [ id  => \qq<lval>,
									  'm' => 1,
									],
							      },
					  'Instances:Auth' => {
							       where => [ id  => \qq<rval>,
									  'm' => 1,
									  ],
							      },
					  'MetaRelation:Auth' => {
								  where => [ 
									    id => \qq<relationid>,
									    w  => 1,
									   ],
								 },
					 ],
			       # Expire a link.  Oddly similar to create (above).
			       expire => [
					  'Instances:Auth' => {
							       where => [
									 id  => \qq<Relations.lval>,
									 'm' => 1,
									],
							      },
					  'Instances:Auth' => {
							       where => [
									 id  => \qq<Relations.rval>,
									 'm' => 1,
									],
							      },
					  'MetaRelation:Auth' => { 
								  where => [
									    id => \qq<Relations.relationid>,
									    w  => 1,
									   ],
								 },
					 ],
			       # Read a link, ie, follow it.
			       fetch => [
					 ':Auth' => {
						     where => [
							       id => \qq<Relations.relationid>,
							       r  => 1,
							      ],
						    },
					],
			       # Update, NOT allowed.
			       update => undef,
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
  
    my $id = $self->storage()->store( "MetaRelation",
				      key    => [ qw/label lval rval/],
				      fields => {
						 label => $label,
						 lval  => $lval,
						 rval  => $rval,
						 l2r   => $params{l2r},
						 r2l   => $params{r2l},
						 
						 requirement => $params{requirement},				      
						});
    return unless $self->get_status()->OK();

    my $user = $self->storage()->user();
    for my $role ( $user->member_of() ) {
	$role->grant( 'MetaRelation' => 'm', id => $id );
    }

    return $id;
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
