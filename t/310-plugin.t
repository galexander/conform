#!perl
# Tests for Conform::Plugin
use strict;
use Test::More tests => 30;
use Test::Trap;
use Data::Dumper;
use Scalar::Util qw(refaddr);

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
can_ok 'Conform::Plugin', 'MODIFY_CODE_ATTRIBUTES';
can_ok 'Conform::Plugin', 'FETCH_CODE_ATTRIBUTES';

my $plugin;

trap { $plugin = Conform::Plugin->new(); };
ok $trap->die, 'Constructor died OK - missing required parameters - ALL';
trap { $plugin = Conform::Plugin->new(name => 'foo'); };
ok $trap->die, 'Constructor died OK - missing required parameters - version';
trap { $plugin = Conform::Plugin->new(name => 'foo', version => "1.1"); };
ok $trap->die, 'Constructor died OK - missing required parameters - impl';
trap { $plugin = Conform::Plugin->new(name => 'foo', version => "1.1", impl => sub { }); };
ok $trap->die, 'Constructor died OK - missing required parameters - attr';
trap { $plugin = Conform::Plugin->new(name => 'foo', version => "1.1", impl => sub { }, attr => []); };
is ($trap->stderr, /abstract/, 'Constructor died OK - abstract class');

use_ok 'Test::Conform::Mock::Plugin';
sub impl {
    print "@{[shift]} IMPL OK\n";
}
$plugin = new Test::Conform::Mock::Plugin
                name => 'mock',
                version => '1.0',
                impl => \&impl,
                attr => [ 'value1',  { key => 'value2' }, [ 'elem1=value3' ], { key => 'value4', 'elem1' => 'value5' }, [ 'key=value6' ]  ];

is ($plugin->name, 'mock', 'name set OK');
is ($plugin->version, '1.0', 'version set OK');
is (refaddr $plugin->impl, refaddr \&impl, 'impl set OK');
is_deeply($plugin->attr, [ 'value1', { key => 'value2' }, [ 'elem1=value3' ], { key => 'value4', 'elem1' => 'value5' }, [ 'key=value6' ] ],
            'attr set OK');
is ($plugin->id, 'mock-1.0', 'id set OK');
is ($plugin->type, 'Mock', 'type set OK');
trap { $plugin->impl->('test') };
is ($trap->stdout, "test IMPL OK\n", "plugin->impl behaves correctly");
is ($plugin->get_attr('value1'), 1, "get_attr('value1') == 1");
is ($plugin->get_attr('elem1'), 'value3', "get_attr('elem1') == value3");
is ($plugin->get_attr('key'), 'value2', "get_attr('key') == value2");
is_deeply([$plugin->get_attrs('key')], [ 'value2', 'value4', 'value6' ], "get_attrs('key') = [ 'value2', 'value4', 'value6' ]");
is_deeply([$plugin->get_attrs('elem1')], [ 'value3', 'value5' ], "get_attrs('key') = [ 'value3', 'value5' ]");
