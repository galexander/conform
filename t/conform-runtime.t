package Conform::Runtime;
use Test::More qw(no_plan);
use Test::Trap;
use FindBin;

use strict;

BEGIN {
    use lib "$FindBin::Bin/../lib";
    use_ok 'Conform::Runtime';
}

can_ok 'Conform::Runtime', 'new';
can_ok 'Conform::Runtime', 'name';

my $runtime;

$runtime = Conform::Runtime->new();

ok $runtime,    "@{[ ref $runtime ]} created";

# vi: set ts=4 sw=4:
# vi: set expandtab:
