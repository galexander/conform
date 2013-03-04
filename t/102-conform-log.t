package Conform::Test::Log;
use Test::More tests => 5;

use FindBin;
use lib "$FindBin::Bin/../lib";
use_ok "Conform::Log";
is ($Conform::Log::VERSION, $Conform::VERSION, 'version OK');

can_ok 'Conform::Log', qw(new messages get_messages append);

my $log = Conform::Log->new();
isa_ok $log, 'Conform::Log';

$log->append("hello");

is $log->get_messages, "hello\n", "message append OK";


# vi: set ts=4 sw=4:
# vi: set expandtab:
