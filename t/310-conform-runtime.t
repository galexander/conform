#!perl
use strict;
use Test::More tests => 16;
use Test::Trap;
use FindBin;
use lib "$FindBin::Bin/../lib";

use_ok 'Conform::Runtime';
can_ok 'Conform::Runtime', 'new';
can_ok 'Conform::Runtime', 'name';
can_ok 'Conform::Runtime', 'version';
can_ok 'Conform::Runtime', 'id';
can_ok 'Conform::Runtime', 'inheritance';
can_ok 'Conform::Runtime', 'providers';
can_ok 'Conform::Runtime', 'action_providers';
can_ok 'Conform::Runtime', 'task_providers';
can_ok 'Conform::Runtime', 'data_providers';
can_ok 'Conform::Runtime', 'find_provider';
can_ok 'Conform::Runtime', 'boot';

# check constructor without named parameters
my $runtime = Conform::Runtime->new();

is($runtime->name, blessed $runtime, 
   'Runtime name set to correct value -> ' . $runtime->name);
is($runtime->version, $Conform::Runtime::VERSION,
   'Runtime version set to correct value -> ' . $runtime->version); 
is($runtime->id, sprintf("%s-%s", blessed $runtime, $Conform::Runtime::VERSION),
   'Runtime id set to correct value -> ' . $runtime->id);

is_deeply($runtime->inheritance, [ ], 'Inheritance resolution OK');

# vi: set ts=4 sw=4:
# vi: set expandtab:
