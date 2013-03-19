package Conform::Test::Core::IO::Command;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Symbol qw( delete_package );
use Test::More tests => 4;

require_ok('Conform::Core::IO::Command')
	or die "# Conform::Core::IO::Command not available\n";

my @all = qw(
	command
    find_command
);

can_ok('Conform::Core::IO::Command', @all);

sub is_exported_by {
	my ($imports, $expect, $msg) = @_;
	delete_package 'Clean';
	eval '
		package Clean;
		Conform::Core::IO::Command->import(@$imports);
		Test::More::is_deeply([sort keys %Clean::], [sort @$expect], $msg);
	' or die "# $@";
}

is_exported_by([], [], 'nothing is exported by default');
is_exported_by([qw( :all )], \@all, ':all exports all functions');

1;
