package Test::Conform::Queue;
use Test::More qw(no_plan);
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use_ok 'Conform::Queue';

can_ok 'Conform::Queue', 'enqueue';
can_ok 'Conform::Queue', 'dequeue';
can_ok 'Conform::Queue', 'size';
can_ok 'Conform::Queue', 'extract';
can_ok 'Conform::Queue', 'extract_single';
can_ok 'Conform::Queue', 'extract_multi';
can_ok 'Conform::Queue', 'remove';
can_ok 'Conform::Queue', 'remove_at';
can_ok 'Conform::Queue', 'insert';
can_ok 'Conform::Queue', 'insert_at';
can_ok 'Conform::Queue', 'find';
can_ok 'Conform::Queue', 'find_single';
can_ok 'Conform::Queue', 'find_multi';
can_ok 'Conform::Queue', 'traverse';

# vi: set ts=4 sw=4:
# vi: set expandtab:
