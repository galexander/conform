use Test::More qw(no_plan);
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Scalar::Util qw(refaddr);
use_ok 'Conform::Action';

my @methods = qw(new
                 id
                 name
                 prio
                 args
                 impl
                 provider
                 execute
                 run
                 complete
                 result
                 dependencies
                 satisfies);
            

can_ok 'Conform::Action', @methods;

my $action_impl = sub { "foo" };
my $action = Conform::Action->new(args => { a => 1, b => 2, }, impl => $action_impl);

isa_ok $action, 'Conform::Action';

ok (!defined($action->id),   'id is not defined');
ok (!defined($action->name), 'name is not defined');
ok (defined ($action->args), 'args is defined');
is ($action->prio, 50,       'prio set correctly');
is_deeply ($action->dependencies,
           [],               'action dependencies not set');

ok(!$action->satisfies({}),   'dependency satisfied');

is_deeply($action->args,
         { a => 1, b => 2 },
                             'args set correctly');

ok (defined ($action->impl), 'impl defined');
is (refaddr $action_impl,
    refaddr $action->impl,
                             'impl set correctly');

is ($action->impl->(),
    "foo",
                             'impl returned correct result');

ok (!$action->complete,      'complete not set ok');

my ($result) = $action->execute;

TODO: {
    local $TODO = 'TBD';
    

};

is ($result, "foo",         'executed ok');
ok ($action->complete,      'complete ok');



# vi: set ts=4 sw=4:
# vi: set expandtab:
