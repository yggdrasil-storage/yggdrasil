package Yggdrasil::Storage::Type;

use strict;
use warnings;

sub new {
    my $class = shift;

    my $self  = {
		 valid_types => {
				 TEXT      => 1,
				 VARCHAR   => 255,
				 BOOLEAN   => 1,
				 SET       => 1,
				 INTEGER   => 1,
				 FLOAT     => 1,
				 TIMESTAMP => 1,
				 DATE      => 1,
				 SERIAL    => 1,
				 BINARY    => 1,
				 PASSWORD  => 1,				  
				},
		};
    
    return bless $self, $class;
}

sub valid_types {
    my $self = shift;
    return keys %{$self->{valid_types}};
}

sub is_valid_type {
    my $self = shift;
    my $type = shift;

    return $self->{valid_types}->{$type};    
}


1;
