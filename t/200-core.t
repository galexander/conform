use warnings;
use strict;

use Symbol qw( delete_package );
use Test::More tests => 18;
use Test::Trap;
use FindBin;
use lib "$FindBin::Bin/../lib";


require_ok('Conform::Core')
	or die "# Conform::Core not available\n";

my @all = qw(
    action timeout safe 
	comma_or_arrayref
	validate
	type_list i_isa_class i_isa_host
	i_isa i_isa_fetchall i_isa_mergeall i_isa_merge
	ints_on_host ips_on_host 
);
my @deprecated = qw(
	build_netgroups expand_netgroup
);

can_ok('Conform::Core', @all, @deprecated);

sub is_exported_by {
	my ($imports, $expect, $msg) = @_;
	delete_package 'Clean';
	eval '
		package Clean;
		Conform::Core->import(@$imports);
		Test::More::is_deeply([sort keys %Clean::], [sort @$expect], $msg);
	' or die "# $@";
}

is_exported_by([], [], 'nothing is exported by default');
is_exported_by([qw( :all )], \@all, ':all exports all non-deprecated functions');
is_exported_by([qw( :deprecated )], \@deprecated, ':deprecated exports all deprecated functions');

# object creation tests
trap { my $obj = Conform::Core->new() };
ok($trap->die, 'Object creation with no params should die');
trap { my $obj = Conform::Core->new( hash => {}) };
ok($trap->die, 'Object creation without host param should die');
trap { my $obj = Conform::Core->new( host => 'foo') };
ok($trap->die, 'Object creation without hash param should die');
for my $hash ('scalar', ['arrayref'], do {\my $scalarref } ) {
    trap { my $obj = Conform::Core->new( hash => $hash, host => 'foo') };
    ok($trap->die, 'Object creation with a non-hash hash param should die');
}
for my $host ({ 'hash' => 'ref' }, ['arrayref'], do {\my $scalarref } ) {
    trap { my $obj = Conform::Core->new( hash => {}, host => $host) };
    ok($trap->die, 'Object creation with a non-scalar host param should die');
}
my $obj;
eval {
    $obj = Conform::Core->new( hash => {}, host => 'foo');
    die unless ref $obj eq 'Conform::Core';
};
ok(! $@, 'No unknown errors or oddities in Conform::Core object creation');
is($obj->iam(), 'foo', 'iam returns correct value');
$obj->iam('bar');
is($obj->iam(), 'bar', 'iam returns changes value of host');
is($obj->iam('shoe'), 'shoe', 'iam returns changes value of host and returns the new value');
