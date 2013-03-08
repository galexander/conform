package Conform::Test::Core::IO;
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Symbol qw( delete_package );
use Test::More tests => 4;

require_ok('Conform::Core::IO')
	or die "# Conform::Core::IO not available\n";

my @all = qw(
	command
	slurp_file slurp_http
	safe_write safe_write_file
	get_attr set_attr
	text_install file_install file_install_http
	file_touch file_append file_modify file_unlink
	file_comment_spec file_comment file_uncomment_spec file_uncomment
	template_install template_file_install template_text_install
	dir_check dir_install dir_install_http
	dir_list dir_list_http
	symlink_check
	this_tty
);

can_ok('Conform::Core::IO', @all);

sub is_exported_by {
	my ($imports, $expect, $msg) = @_;
	delete_package 'Clean';
	eval '
		package Clean;
		Conform::Core::IO->import(@$imports);
		Test::More::is_deeply([sort keys %Clean::], [sort @$expect], $msg);
	' or die "# $@";
}

is_exported_by([], [], 'nothing is exported by default');
is_exported_by([qw( :all )], \@all, ':all exports all functions');

1;
