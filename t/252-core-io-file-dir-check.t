use strict;
use warnings;

use File::Spec;
use File::Temp;
use Test::File;
use Test::More tests => 29;
use Test::Trap;
use FindBin;

BEGIN {
    use lib "$FindBin::Bin/../lib";
    use_ok('Conform::Core::IO', qw( command ));
	use_ok('Conform::Core::IO::File', qw( dir_check ))
		or die "# Conform::Core::IO::File not available\n";
}

my $dirname  = File::Temp::tempdir(CLEANUP => 1);
my $filename = File::Spec->catfile($dirname, 'file');
my $subdir1  = File::Spec->catdir($dirname, 'dir1');
my $subdir2  = File::Spec->catdir($subdir1, 'dir2');
my $subdir3  = File::Spec->catdir($subdir1, 'dir3');
my $subdir4  = File::Spec->catdir($subdir1, 'dir4');

my $updated;

my $status = command '/bin/touch', $filename;
is($status, 0, 'file prepared');

############################################################################

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { dir_check $subdir2 };
	ok($updated, 'safe mode: dir_check returns true');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Creating directory $subdir1 with mode 755
SKIPPING: Creating directory $subdir2 with mode 755
EOF
	file_not_exists_ok($subdir1, '  directory 1 is not created');
	file_not_exists_ok($subdir2, '  directory 2 is not created');
}

$updated = trap { dir_check $subdir2 };
ok($updated, 'dir_check returns true');
is($trap->stderr, <<EOF, 'dir_check logs creation');
Creating directory $subdir1 with mode 755
Creating directory $subdir2 with mode 755
EOF
file_mode_is($subdir1, 0755, '  directory 1 is created');
file_mode_is($subdir2, 0755, '  directory 2 is created');

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { dir_check $subdir2 };
	ok(!$updated, 'safe mode: dir_check returns false if directory exists (safe mode)');
	is($trap->die, undef, '  but did not croak (safe mode)');
}

$updated = trap { dir_check $subdir2 };
ok(!$updated, 'dir_check returns false if directory exists');
is($trap->die, undef, '  but did not croak');

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { dir_check $subdir3, { mode => 0700 } };
	ok($updated, 'dir_check returns true with directory mode (legacy) (safe mode)');
	is($trap->stderr, <<EOF, '  log is correct (safe mode)');
SKIPPING: Creating directory $subdir3 with mode 700
EOF
	file_not_exists_ok($subdir3, '  directory 3 is not created (safe mode)');
}

$updated = trap { dir_check $subdir3, { mode => 0700 } };
ok($updated, 'dir_check returns true with directory mode (legacy)');
is($trap->stderr, <<EOF, '  log is correct');
Creating directory $subdir3 with mode 700
EOF
file_mode_is($subdir3, 0700, '  directory 3 is created correctly');

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { dir_check $subdir4, undef, { mode => 0700 } };
	ok($updated, 'dir_check returns true with directory mode (safe mode)');
	is($trap->stderr, <<EOF, '  log is correct (safe mode)');
SKIPPING: Creating directory $subdir4 with mode 700
EOF
	file_not_exists_ok($subdir4, '  directory 4 is not created (safe mode)');
}

$updated = trap { dir_check $subdir4, undef, { mode => 0700 } };
ok($updated, 'dir_check returns true with directory mode');
is($trap->stderr, <<EOF, '  log is correct');
Creating directory $subdir4 with mode 700
EOF
file_mode_is($subdir4, 0700, '  directory 4 is created correctly');

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { dir_check $filename };
	ok($trap->die, 'safe mode: dir_check croaks on non-directory');
}

$updated = trap { dir_check $filename };
ok($trap->die, 'dir_check croaks on non-directory');
