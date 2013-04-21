#!perl
# Tests for Conform::Plugin
use strict;
use Test::More tests => 11;

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/lib";

use Conform;

use_ok 'Conform::Plugin';
is $Conform::Plugin::VERSION, $Conform::VERSION, 'version OK';
can_ok 'Conform::Plugin', 'id';
can_ok 'Conform::Plugin', 'name';
can_ok 'Conform::Plugin', 'version';
can_ok 'Conform::Plugin', 'type';
can_ok 'Conform::Plugin', 'impl';
can_ok 'Conform::Plugin', 'attr';
can_ok 'Conform::Plugin', 'get_attr';
can_ok 'Conform::Plugin', 'get_attrs';
can_ok 'Conform::Plugin', 'extract_directives';
