package Conform::Action;
use Test::More qw(no_plan);
use strict;
use FindBin;

BEGIN {
    use lib "$FindBin::Bin/../lib";
    use_ok 'Conform::Action';
}

can_ok 'Conform::Action', 'name';
can_ok 'Conform::Action', 'impl';
can_ok 'Conform::Action', 'execute';
can_ok 'Conform::Action', 'dependencies';

# vi: set ts=4 sw=4:
# vi: set expandtab:
