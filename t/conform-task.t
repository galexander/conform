package Conform::Task;
use Test::More qw(no_plan);
use strict;
use FindBin;

BEGIN {
    use lib "$FindBin::Bin/../lib";
    use_ok 'Conform::Task';
}

can_ok 'Conform::Task', 'name';
can_ok 'Conform::Task', 'impl';
can_ok 'Conform::Task', 'execute';

# vi: set ts=4 sw=4:
# vi: set expandtab:
