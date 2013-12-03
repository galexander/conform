#!perl
use strict;
use Test::More qw(no_plan);
use Test::Trap;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Data::Dump qw(dump);
use Conform::Logger;


use_ok 'Conform::Runtime::Server::Posix';
can_ok 'Conform::Runtime::Server::Posix', 'new';
can_ok 'Conform::Runtime::Server::Posix', 'data_providers';
can_ok 'Conform::Runtime::Server::Posix', 'action_providers';
can_ok 'Conform::Runtime::Server::Posix', 'boot';

my $runtime = Conform::Runtime::Server::Posix->new();
$runtime->boot;


# vi: set ts=4 sw=4:
# vi: set expandtab:
