use strict;
use warnings;

use File::Spec;
use File::Temp;
use Test::More tests => 40;
use Test::File;
use Test::Trap;
use FindBin;

BEGIN {
    use lib "$FindBin::Bin/../lib";
    use_ok('Conform::Core::IO', qw( command ));
	use_ok('Conform::Core::IO::File', qw( set_attr get_attr ))
		or die "# Conform::Core::IO::File not available\n";
}

my $dirname  = File::Temp::tempdir(CLEANUP => 1);
my $filename = File::Spec->catfile($dirname, 'file');
my $missing  = File::Spec->catfile($dirname, 'missing');

my $updated;

my $status = command '/bin/touch', $filename;
is($status, 0, 'file prepared');

my $ok = chmod 0000, $filename;
ok($ok, '  and chmodded');

############################################################################


{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { set_attr $missing, { mode => 0644 } };
	ok(!$updated, 'safe mode: set_attr returns false on missing file');
	is($trap->stderr, <<EOF, '  log is correct');
EOF
}

$updated = trap { set_attr $missing, { mode => 0644 } };
ok(!$updated, 'set_attr croaks on missing file');

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { set_attr $filename, { mode => 0644 } };
	ok($updated, 'safe mode: set_attr returns true (numeric)');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Changing mode of $filename to 644
EOF
	file_mode_is($filename, 0000, '  file mode is not changed');
}

$updated = trap { set_attr $filename, { mode => 0644 } };
ok($updated, 'set_attr returns true (numeric)');
is($trap->stderr, <<EOF, '  log is correct');
Changing mode of $filename to 644
EOF
file_mode_is($filename, 0644, '  file mode is changed');

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { set_attr $filename, { mode => 'rw-r-----' } };
	ok($updated, 'safe mode: set_attr returns true (symbolic)');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Changing mode of $filename to 640
EOF
	file_mode_is($filename, 0644, '  file mode is not changed');
}

$updated = trap { set_attr $filename, { mode => 'rw-r-----' } };
ok($updated, 'set_attr returns true (numeric)');
is($trap->stderr, <<EOF, '  log is correct');
Changing mode of $filename to 640
EOF
file_mode_is($filename, 0640, '  file mode is changed correctly');

SKIP: {
	skip 'not a superuser',       16 unless $> == 0;
	skip 'not in the supergroup', 16 unless $) == 0;
	my $root_user  = getpwuid $>;
	my $root_group = getpwuid $);

	SKIP: {
		local $Conform::Core::safe_mode = 1;
		$updated = trap { set_attr $filename, { owner => 42, group => 42 } };
		ok($updated, 'safe mode: set_attr returns true (numeric owner/group)');
		is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Changing ownership of $filename to 42:42
EOF
		owner_is($filename, $>, '  file owner is not changed');
		skip 'group_is not available', 1 unless defined &group_is;
		&group_is($filename, $), '  file group is not changed');
	}

	$updated = trap { set_attr $filename, { owner => 42, group => 42 } };
	ok($updated, 'set_attr returns true (numeric owner/group)');
	is($trap->stderr, <<EOF, ' log is correct');
Changing ownership of $filename to 42:42
EOF
	owner_is($filename, 42, '  file owner is changed (numeric)');
	SKIP: {
		skip 'group_is not available', 1 unless defined &group_is;
		&group_is($filename, 42, '  file group is changed (numeric)');
	}

	SKIP: {
		local $Conform::Core::safe_mode = 1;
		$updated = trap { set_attr $filename, { owner => $root_user, group => $root_group } };
		ok($updated, 'safe mode: set_attr returns true (named owner/group)');
		is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Changing ownership of $filename to 0:0
EOF
		owner_is($filename, 42, '  file owner is not changed');
		skip 'group_is not available', 1 unless defined &group_is;
		&group_is($filename, 42, '  file group is not changed');
	}

	$updated = trap { set_attr $filename, { owner => $root_user, group => $root_group } };
	ok($updated, 'set_attr returns true (named owner/group)');
	is($trap->stderr, <<EOF, '  log is correct');
Changing ownership of $filename to 0:0
EOF
	owner_is($filename, $>, '  file owner is changed (name)');
	SKIP: {
		skip 'group_is not available', 1 unless defined &group_is;
		&group_is($filename, $), '  file group is changed (name)');
	}
}

is_deeply ([get_attr $missing], [], 'get_attr returns an empty list for missing file');
$ok = trap { set_attr $filename, { mode => 0600, uid => $>, gid => (split / /, $))[0] } };
ok ($ok, ' set attr successful');
is ($trap->stderr, <<EOF, ' log is correct');
Changing mode of $filename to 600
EOF

file_mode_is ($filename, 0600, 'file mode set correctly');
is_deeply ({get_attr $filename}, { mode => 0600, uid => $>, gid => (split / /, $))[0], ($^O eq 'linux' ? (append_only => 0, immutable => 0) : ()) } ,
'get_attr returns correct result for filename');
