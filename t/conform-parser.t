#!/usr/bin/perl -w

use strict;
use FindBin;
use Test::More tests => 50;
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



1;
