#!perl
# Tests for Conform::Action
use strict;
use Test::More tests => 14;

use FindBin;
use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/lib";

use Conform;

use_ok 'Conform::Action::Plugin';
isa_ok 'Conform::Action::Plugin', 'Conform::Plugin';
isa_ok 'Conform::Action::Plugin', 'Conform::Work::Plugin';
is $Conform::Action::Plugin::VERSION, $Conform::VERSION, 'version OK';
can_ok 'Conform::Action::Plugin', 'id';
can_ok 'Conform::Action::Plugin', 'name';
can_ok 'Conform::Action::Plugin', 'version';
can_ok 'Conform::Action::Plugin', 'impl';
can_ok 'Conform::Action::Plugin', 'type';
can_ok 'Conform::Action::Plugin', 'impl';
can_ok 'Conform::Action::Plugin', 'attr';
can_ok 'Conform::Action::Plugin', 'get_attr';
can_ok 'Conform::Action::Plugin', 'get_attrs';
can_ok 'Conform::Action::Plugin', 'extract_directives';

