#!perl
use strict;
use Test::More tests => 24;
use Test::Trap;
use FindBin;
use lib "$FindBin::Bin/../lib";

use_ok 'Conform::Runtime';
can_ok 'Conform::Runtime', 'new';
can_ok 'Conform::Runtime', 'name';
can_ok 'Conform::Runtime', 'version';
can_ok 'Conform::Runtime', 'id';
can_ok 'Conform::Runtime', 'action_providers';
can_ok 'Conform::Runtime', 'task_providers';
can_ok 'Conform::Runtime', 'data_providers';
can_ok 'Conform::Runtime', 'boot';


# check constructor without named parameters
my $runtime = Conform::Runtime->new();
ok($runtime->name, 'Runtime name set ' . $runtime->name);
ok($runtime->version, 'Runtime version set ' . $runtime->version);
ok($runtime->id, 'Runtime id set ' . $runtime->id);

# ensure that name, version and id are
# immutable once they are set
for (qw(name version id)) {
    trap { $runtime->$_($_); };
    ok ($trap->die, "setting $_ died OK trying to set immutable value");
}

# check constructor with named paramters
$runtime = Conform::Runtime->new(name => "foo", version => "1.0", id => "foo-1.0");

is($runtime->name, "foo", 'Runtime name set ' . $runtime->name);
is($runtime->version, "1.0", 'Runtime version set ' . $runtime->version);
is($runtime->id, "foo-1.0", 'Runtime id set ' . $runtime->id);

# check parameter validation
trap { $runtime = Conform::Runtime->new(name => "232323") };
ok($trap->die, "died OK setting name to invalid value");

trap { $runtime = Conform::Runtime->new(name => "foo::bar::") };
ok($trap->die, "died OK setting name to invalid value");

trap { $runtime = Conform::Runtime->new(version => "abasd") };
ok($trap->die, "died OK setting version to invalid value");

trap { $runtime = Conform::Runtime->new(version => "v0.1.") };
ok($trap->die, "died OK setting version to invalid value");

trap { $runtime = Conform::Runtime->new(id => "abasd") };
ok($trap->die, "died OK setting id to invalid value");

trap { $runtime = Conform::Runtime->new(id => "asdads::-v1.0") };
ok($trap->die, "died OK setting id to invalid value");

# vi: set ts=4 sw=4:
# vi: set expandtab:
