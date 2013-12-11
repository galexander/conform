#!/usr/bin/perl -w

use strict;
use FindBin;
use Test::More tests => 58;
use Test::Trap;
use Data::Dumper;

BEGIN {
    use lib "$FindBin::Bin/../lib";
}

use_ok 'Conform::Parser';

can_ok 'Conform::Parser',
            qw(parse
               parse_file
               grammar
               parser);



my $parser = Conform::Parser->new();

isa_ok $parser, 'Conform::Parser';

my $scalar;

$scalar = $parser->parser->scalar(qq(some.scalar));
is $scalar->[1], 'scalar', 'parse scalar type';
is $scalar->[2], 'some.scalar', 'parse scalar';
$scalar = $parser->xform($scalar);
is $scalar, 'some.scalar', 'xform scalar';

$scalar = $parser->parser->scalar(qq("some quoted scalar"));
is $scalar->[1], 'scalar', 'parse quoted scalar type';
is $scalar->[2], '"some quoted scalar"', 'parse quoted scalar';
$scalar = $parser->xform($scalar);
is $scalar, 'some quoted scalar', 'xform quoted scalar';

$scalar = $parser->parser->scalar(1);
is $scalar->[1], 'scalar', 'parse numeric scalar type';
is $scalar->[2], 1, 'parse numeric scalar';
$scalar = $parser->xform($scalar);
is $scalar, 1, 'xform numeric scalar';

$scalar = $parser->parser->scalar(qq("some quoted; scalar"));
is $scalar->[1], 'scalar', 'parse quoted; scalar type';
is $scalar->[2], '"some quoted; scalar"', 'parse quoted; scalar';
$scalar = $parser->xform($scalar);
is $scalar, 'some quoted; scalar', 'xform quoted; scalar';

$scalar = $parser->parser->scalar(qq("some quoted, scalar"));
is $scalar->[1], 'scalar', 'parse quoted, scalar type';
is $scalar->[2], '"some quoted, scalar"', 'parse quoted, scalar';
$scalar = $parser->xform($scalar);
is $scalar, 'some quoted, scalar', 'xform quoted, scalar';

$scalar = $parser->parser->scalar(qq(some-scalar));
is $scalar->[1], 'scalar', 'parse some-scalar scalar type';
is $scalar->[2], 'some-scalar', 'parse some-scalar';
$scalar = $parser->xform($scalar);
is $scalar, 'some-scalar', 'xform some-scalar';

$scalar = $parser->parser->scalar(qq(some/scalar));
is $scalar->[1], 'scalar', 'parse some/scalar scalar type';
is $scalar->[2], 'some/scalar', 'parse some/scalar';
$scalar = $parser->xform($scalar);
is $scalar, 'some/scalar', 'xform some/scalar';

$scalar = $parser->parser->scalar(qq(some\\scalar));
is $scalar->[1], 'scalar', 'parse some\scalar scalar type';
is $scalar->[2], 'some\scalar', 'parse some\scalar';
$scalar = $parser->xform($scalar);
is $scalar, 'some\scalar', 'xform some\scalar';

$scalar = $parser->parser->scalar(qq(some:scalar));
is $scalar->[1], 'scalar', 'parse some:scalar scalar type';
is $scalar->[2], 'some:scalar', 'parse some:scalar';
$scalar = $parser->xform($scalar);
is $scalar, 'some:scalar', 'xform some:scalar';

$scalar = $parser->parser->scalar(qq(some_scalar));
is $scalar->[1], 'scalar', 'parse some_scalar scalar type';
is $scalar->[2], 'some_scalar', 'parse some_scalar';
$scalar = $parser->xform($scalar);
is $scalar, 'some_scalar', 'xform some_scalar';

$scalar = $parser->parser->scalar(qq(:undef));
is $scalar->[1], 'scalar', 'parse undef scalar type';
is $scalar->[2], ':undef', 'parse undef';
$scalar = $parser->xform($scalar);
is $scalar, undef, 'xform undef scalar';

$scalar = $parser->parser->scalar(qq(::undef));
is $scalar->[1], 'scalar', 'parse escaped undef scalar type';
is $scalar->[2], '::undef', 'parse escaped undef';
$scalar = $parser->xform($scalar);
is $scalar, ':undef', 'xform escaped undef scalar';

my $list;

$list = $parser->parser->list(q{[1,2,a,b,"c"]});
is $list->[1], 'list', 'parse list type';
$list = $parser->xform($list);
is_deeply $list, [1,2,'a','b','c'], 'list xform';

$list = $parser->parser->list(q{[1,2,[3,4],5]});
is $list->[1], 'list', 'parse complex list type';
$list = $parser->xform($list);
is_deeply $list, [1,2,[3,4],5], 'complex list xform';

$list = $parser->parser->list(q{[1,"quoted list element", 3]});
is $list->[1], 'list', 'parse quoted element list type';
$list = $parser->xform($list);
is_deeply $list, [1,'quoted list element', 3], 'quoted element list xform';

$list = $parser->parser->list(q{[1,2,3],});
is $list->[1], 'list', 'parse delimitted list type';
$list = $parser->xform($list);
is_deeply $list, [1,2,3], 'parse delimited list';


my $hash;

$hash = $parser->parser->hash(q"{ key => value }");
is $hash->[1], 'hash', 'parse hash type';
$hash = $parser->xform($hash);
is_deeply $hash, { key => 'value' }, 'hash xform';

$hash = $parser->parser->hash(q'{ "quoted key" => value }');
is $hash->[1], 'hash', 'parse hash type with "quoted key"';
$hash = $parser->xform($hash);
is_deeply $hash, { "quoted key" => 'value' }, 'hash with quoted key xform';

$hash = $parser->parser->hash(q'{ "quoted key" => "quoted value" }');
is $hash->[1], 'hash', 'parse hash type with "quoted value"';
$hash = $parser->xform($hash);
is_deeply $hash, { "quoted key" => 'quoted value' }, 'hash with quoted value xform';

$hash = $parser->parser->hash(q'{ key => value, list => [1,2,3, { a => "b" }, [4,5] ] }');
is $hash->[1], 'hash', 'parse complex hash type';
$hash = $parser->xform($hash);
is_deeply $hash, { key => 'value', list => [1,2,3, { a => "b" }, [4,5]] }, 'hash xform';

$hash = $parser->parser->hash(q"{ key => value },");
is $hash->[1], 'hash', 'parse delimitted hash type';
$hash = $parser->xform($hash);
is_deeply $hash, { key => 'value' }, 'delimitted hash xform';


my $action;

$action = q'
    File_install /file/dst {
        src => "/file/src",
        mode => 755
    },
';

my $tree = $parser->parser->action($action);
ok $tree, 'parse action';
is $tree->[1], 'action', 'parse action type';
$action = $parser->process_site_node_action($tree->[2]);
ok $action, 'processed action';
is_deeply $action,
          { '.id' => '/file/dst', '.name' => 'File_install', '.value' => { 'mode' => '755',  'src' => '/file/src' } },
          'action processed correctly';

my $block;

$block = q"
    Resolver {
        search_domain => ['com', 'example.com']
    },
";

$tree = $parser->parser->block($block);
ok $tree, 'parse block';
is $tree->[1], 'block', 'parse block type';
$block = $parser->process_site_node_block($tree->[2]);
ok $block, 'processed block';
is_deeply $block,
          { '.name' => 'Resolver', '.value' => { search_domain => ['com', 'example.com'] } },
          'block processed correctly';


1;
