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

# vi: set ts=4 sw=4:
# vi: set expandtab:
