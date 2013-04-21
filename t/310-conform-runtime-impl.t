#!perl
use strict;
use Test::More tests => 16;
use Test::Trap;
use FindBin;
use lib "$FindBin::Bin/../lib";

use_ok 'Conform::Test::Runtime';
can_ok 'Conform::Test::Runtime', 'new';
can_ok 'Conform::Test::Runtime', 'name';
can_ok 'Conform::Test::Runtime', 'version';
can_ok 'Conform::Test::Runtime', 'id';
can_ok 'Conform::Test::Runtime', 'inheritance';
can_ok 'Conform::Test::Runtime', 'providers';
can_ok 'Conform::Test::Runtime', 'action_providers';
can_ok 'Conform::Test::Runtime', 'task_providers';
can_ok 'Conform::Test::Runtime', 'data_providers';
can_ok 'Conform::Test::Runtime', 'find_provider';
can_ok 'Conform::Test::Runtime', 'boot';

use Conform::Debug;
$Conform::Debug::DEBUG++;

# check constructor without named parameters
my $runtime = Conform::Test::Runtime->new();

is($runtime->name, blessed $runtime, 
   'Runtime name set to correct value -> ' . $runtime->name);
is($runtime->version, $Conform::Runtime::VERSION,
   'Runtime version set to correct value -> ' . $runtime->version); 
is($runtime->id, sprintf("%s-%s", blessed $runtime, $Conform::Runtime::VERSION),
   'Runtime id set to correct value -> ' . $runtime->id);

is_deeply($runtime->inheritance, [ 'Conform::Runtime' ], 'Inheritance resolution OK');


use Data::Dumper;
print Dumper($runtime->providers);

# vi: set ts=4 sw=4:
# vi: set expandtab:
