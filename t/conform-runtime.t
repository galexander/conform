package Conform::Runtime;
use Test::More qw(no_plan);
use strict;
use FindBin;

BEGIN {
    use lib "$FindBin::Bin/../lib";
    use_ok 'Conform::Runtime';
}

can_ok 'Conform::Runtime', 'new';
can_ok 'Conform::Runtime', 'name';
can_ok 'Conform::Runtime', 'data';

package Conform::Runtime::Tester;
use Mouse;
extends 'Conform::Runtime';


Conform::Logger->set('Stderr');

my $runtime = Conform::Runtime::Tester->new
                ( plugin_search_dirs =>  ["$FindBin::Bin/data/plugins"],
                  plugin_search_paths => ['Runtime'] );

for my $task (keys %{$runtime->tasks}) {
    $runtime->execute($runtime->tasks->{$task})
}


# vi: set ts=4 sw=4:
# vi: set expandtab:
