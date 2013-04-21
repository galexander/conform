#!perl
# Tests for Conform::Work
use strict;
use Test::More tests => 11;

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/lib";

use Conform;

use_ok 'Conform::Work::Plugin';
is $Conform::Work::Plugin::VERSION, $Conform::VERSION, 'version OK';
can_ok 'Conform::Work::Plugin', 'id';
can_ok 'Conform::Work::Plugin', 'name';
can_ok 'Conform::Work::Plugin', 'version';
can_ok 'Conform::Work::Plugin', 'type';
can_ok 'Conform::Work::Plugin', 'impl';
can_ok 'Conform::Work::Plugin', 'attr';
can_ok 'Conform::Work::Plugin', 'get_attr';
can_ok 'Conform::Work::Plugin', 'get_attrs';
can_ok 'Conform::Work::Plugin', 'extract_directives';
