#!perl
use Test::More qw(no_plan);
use FindBin;
use lib "$FindBin::Bin/../lib";

use_ok 'Conform::Scheduler';
use_ok 'Conform::Queue';
use_ok 'Conform::Action';


can_ok 'Conform::Scheduler', 'new';
can_ok 'Conform::Scheduler', 'schedule';
can_ok 'Conform::Scheduler', 'run';
can_ok 'Conform::Scheduler', 'execute';
