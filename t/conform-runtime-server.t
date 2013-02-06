#!perl
use strict;
use Test::More qw(no_plan);
use Test::Trap;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Data::Dump qw(dump);


use_ok 'Conform::Runtime::Server';
can_ok 'Conform::Runtime::Server', 'new';
can_ok 'Conform::Runtime::Server', 'id';
can_ok 'Conform::Runtime::Server', 'version';
can_ok 'Conform::Runtime::Server', 'data_providers';
can_ok 'Conform::Runtime::Server', 'action_providers';
can_ok 'Conform::Runtime::Server', 'boot';

use Conform::Debug;

$Conform::Debug::DEBUG++ if grep /-d/, @ARGV;


my $runtime = Conform::Runtime::Server->new();
$runtime->boot;

printf "Id=%s Name=%s Version=%s\n", $runtime->getId(),
                     $runtime->getName(),
                     $runtime->getVersion();






# vi: set ts=4 sw=4:
# vi: set expandtab:
