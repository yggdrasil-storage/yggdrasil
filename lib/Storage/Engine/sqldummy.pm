package Storage::Engine::sqldummy;

use strict;
use warnings;

use base 'Storage::Engine::Shared::SQL';
our $VERSION = '0.1';

sub new { bless {}, shift; }
sub engine_type { $_[0]->_engine(); }
sub engine_version { $VERSION; }
sub maxid { 42; }
sub info { ""; }
sub size { 1; }
sub storage_is_empty { 1; }
sub _structure_exists { 0; }
sub _list_structures { (); }
sub _fields_in_structure { (); }
sub _map_type { return $_[1]; }
sub _null_comparison_operator { 'is'; }
1;
