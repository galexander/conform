#!perl
use strict;
use Test::More qw(no_plan);
use Test::Trap;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Data::Dump qw(dump);


use_ok 'Conform::Runtime';
can_ok 'Conform::Runtime', 'new';
can_ok 'Conform::Runtime', 'id';
can_ok 'Conform::Runtime', 'version';
can_ok 'Conform::Runtime', 'data_providers';
can_ok 'Conform::Runtime', 'action_providers';
can_ok 'Conform::Runtime', 'boot';

use Conform::Debug;

$Conform::Debug::DEBUG++ if grep /-d/, @ARGV;


my $runtime = Conform::Runtime->new();
$runtime->boot;






# vi: set ts=4 sw=4:
# vi: set expandtab:
