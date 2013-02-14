#!perl
use Test::More qw(no_plan);
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Scalar::Util qw(refaddr);
use_ok 'Conform::Task';

my @methods = qw(new
                 id
                 name
                 prio
                 impl
                 run
                 execute
                 complete
                 result);
            

can_ok 'Conform::Task', @methods;

my $task_impl = sub { "foo" };
my $task = Conform::Task->new(impl => $task_impl);

isa_ok $task, 'Conform::Task';

ok (!defined($task->id),   'id is not defined');
ok (!defined($task->name), 'name is not defined');
is ($task->prio, 50,       'prio set correctly');
is_deeply ($task->dependencies,
           [],               'task dependencies not set');

ok (defined ($task->impl), 'impl defined');
is (refaddr $task_impl,
    refaddr $task->impl,
                             'impl set correctly');

is ($task->impl->(),
    "foo",
                             'impl returned correct result');

ok (!$task->complete,      'complete not set ok');

my ($result) = $task->execute;

TODO: {
    local $TODO = 'TBD';
    

};

is ($result, "foo",         'executed ok');
ok ($task->complete,      'complete ok');



# vi: set ts=4 sw=4:
# vi: set expandtab:
