package Conform::Executable;
use Test::More qw(no_plan);
use strict;
use FindBin;

BEGIN {
    use lib "$FindBin::Bin/../lib";
    use_ok 'Conform::Executable';
}

can_ok 'Conform::Executable', 'name';
can_ok 'Conform::Executable', 'impl';
can_ok 'Conform::Executable', 'execute';

# vi: set ts=4 sw=4:
# vi: set expandtab:
