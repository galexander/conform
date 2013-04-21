#!perl
# Tests for Conform::Task
use strict;
use Test::More tests => 11;

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/lib";

use Conform;

use_ok 'Conform::Task::Plugin';
is $Conform::Task::Plugin::VERSION, $Conform::VERSION, 'version OK';
can_ok 'Conform::Task::Plugin', 'id';
can_ok 'Conform::Task::Plugin', 'name';
can_ok 'Conform::Task::Plugin', 'version';
can_ok 'Conform::Task::Plugin', 'type';
can_ok 'Conform::Task::Plugin', 'impl';
can_ok 'Conform::Task::Plugin', 'attr';
can_ok 'Conform::Task::Plugin', 'get_attr';
can_ok 'Conform::Task::Plugin', 'get_attrs';
can_ok 'Conform::Task::Plugin', 'extract_directives';
