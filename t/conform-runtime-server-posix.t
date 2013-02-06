#!perl
use strict;
use Test::More qw(no_plan);
use Test::Trap;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Data::Dump qw(dump);
use Conform::Logger;

Conform::Logger->set('Stderr');


use_ok 'Conform::Runtime::Server::Posix';
can_ok 'Conform::Runtime::Server::Posix', 'new';
can_ok 'Conform::Runtime::Server::Posix', 'data_providers';
can_ok 'Conform::Runtime::Server::Posix', 'action_providers';
can_ok 'Conform::Runtime::Server::Posix', 'boot';

use Conform::Debug;

$Conform::Debug::DEBUG++ if grep /-d/, @ARGV;
$Conform::Debug::TRACE++ if grep /-t/, @ARGV;



my $runtime = Conform::Runtime::Server::Posix->new();
$runtime->boot;

printf "Id=%s Name=%s Version=%s\n", $runtime->getId(),
                     $runtime->getName(),
                     $runtime->getVersion();


# vi: set ts=4 sw=4:
# vi: set expandtab:
