use strict;
use warnings;

use File::Spec;
use File::Temp;
use Test::More tests => 31;
use Test::File;
use Test::Files;
use Test::Trap;
use FindBin;

BEGIN {
    use lib "$FindBin::Bin/../lib";
    use_ok('Conform::Core::IO::Command', qw( find_command ));
	use_ok('Conform::Core::IO::File', qw( text_install dir_install ))
		or die "# Conform::Core::IO::File not available\n";
}

use Conform::Logger;
Conform::Logger->configure('stderr' => { formatter => { default => '%m' } });


my $dirname    = File::Temp::tempdir(CLEANUP => 1);
my $subdir1    = File::Spec->catdir($dirname, 'dir1');
my $filename1  = File::Spec->catfile($subdir1, 'file1');
my $filename2  = File::Spec->catfile($subdir1, 'file2');
my $subdir2    = File::Spec->catdir($dirname, 'dir2');
my $filename3  = File::Spec->catfile($subdir2, 'file1');
my $filename4  = File::Spec->catfile($subdir2, 'file2');
my $rcssubdir1 = File::Spec->catdir($subdir2, 'RCS');
my $subdir3    = File::Spec->catdir($dirname, 'dir3');
my $filename5  = File::Spec->catfile($subdir3, 'file1');
my $filename6  = File::Spec->catfile($subdir3, 'file2');
my $rcssubdir2 = File::Spec->catdir($subdir3, 'RCS');

my $updated;

my $have_rcs = find_command 'ci' && find_command 'co';

$updated = trap { text_install $filename1, 'foo' };
ok($updated, 'file 1 prepared')
	or die "# Could not prepare file 1\n";
$updated = trap { text_install $filename2, 'bar' };
ok($updated, 'file 2 prepared')
	or die "# Could not prepare file 2\n";

############################################################################

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { dir_install $subdir2, $subdir1, '/bin/echo done', undef, sub { s/bar/BAR/g } };
	ok($updated, 'safe mode: dir_install returns true');
	like($trap->stderr, qr/^SKIPPING: Creating directory \Q$subdir2\E with mode 755$/m,
			"  log is correct 'SKIPPING: Creating directory $subdir2'");
	like($trap->stderr, qr/^SKIPPING: Installing '\Q$filename3\E' from \Q$filename1\E$/m,
			"  log is correct 'SKIPPING: Installing '$filename3' from $filename1");
	like($trap->stderr, qr/^SKIPPING: Installing '\Q$filename4\E' from \Q$filename2\E$/m,
			"  log is correct 'SKIPPING: Installing $filename4 from $filename2'");
	like($trap->stderr, qr/^SKIPPING: Running '\/bin\/echo done' to finish install of \Q$subdir2\E$/m,
			"  log is correct 'SKIPPING: Running '/bin/echo done' to finish install of $subdir2'");
	file_not_exists_ok($subdir2, '  destination directory is not created');
}

$updated = trap { dir_install $subdir2, $subdir1, '/bin/echo done', undef, sub { s/bar/BAR/g } };
ok($updated, 'dir_install returns true');
like($trap->stderr, qr/^Creating directory \Q$subdir2\E with mode 755$/m,
	"  log is correct 'Creating directory $subdir2 with mode 755'");
like($trap->stderr, qr/^Installing '\Q$filename3\E' from \Q$filename1\E$/m,
	"  log is correct 'Installing '$filename3' from $filename1'");
SKIP : {
    skip "rcs not available", 1 unless $have_rcs;
    like($trap->stderr, qr/^Creating directory \Q$rcssubdir1\E with mode 700$/m,
	"  log is correct 'Creating directory $rcssubdir1 with mode 700'");
}
like($trap->stderr, qr/^Installing '\Q$filename4\E' from \Q$filename2\E$/m,
	"  log is correct 'Installing '$filename4' from $filename2'");
like($trap->stderr, qr/^Running '\/bin\/echo done' to finish install of \Q$subdir2\E$/m,
	"  log is correct 'Running '/bin/echo done' to finish install of $subdir2");

compare_ok($filename3, $filename1, '  destination file 1 is accurate');
file_ok($filename4, 'BAR', '  destination file 2 is accurate');
SKIP : {
    skip "rcs not available", 1 unless $have_rcs;
    dir_only_contains_ok($rcssubdir1, ['file1,v', 'file2,v'], '  RCS files are created');
}

my $filter = sub { if ($_[2] eq 'file2') { warn "FILTER: @_\n"; return 0 } 1 };

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { dir_install $subdir3, $subdir1, undef, { filter => $filter, rcs => 0 } };
	ok($updated, "safe mode: dir_install returns true with filter@{[$have_rcs ? ' and RCS skipped' : '' ]}");
	like($trap->stderr, qr/^SKIPPING: Creating directory \Q$subdir3\E with mode 755$/m,
		"  log is correct 'SKIPPING: Creating directory $subdir3 with mode 755'");
	like($trap->stderr, qr/^SKIPPING: Installing '\Q$filename5\E' from \Q$filename1\E@{[$have_rcs ? " \(skipped RCS\)" : "" ]}$/m,
		"  log is correct 'SKIPPING: Installing '$filename5' from $filename1@{[$have_rcs ? ' (skipped RCS)' : '' ]}'");
	like($trap->stderr, qr/^FILTER: \Q$subdir3\E \Q$subdir1\E file2$/m,
		"  log is correct 'FILTER: $subdir3 $subdir1 file2'");
	file_not_exists_ok($subdir3, '  destination directory is not created');
}

$updated = trap { dir_install $subdir3, $subdir1, undef, { filter => $filter, rcs => 0 } };
ok($updated, "dir_install returns true with filter@{[$have_rcs ? ' and RCS skipped' : '' ]}");
like($trap->stderr, qr/^Creating directory \Q$subdir3\E with mode 755$/m,
	"  log is correct 'Creating directory $subdir3 with mode 755'");
like($trap->stderr, qr/^Installing '\Q$filename5\E' from \Q$filename1\E@{[$have_rcs ? " \(skipped RCS\)" : "" ]}$/m,
	"  log is correct 'Installing '$filename5' from $filename1@{[$have_rcs ? ' (skipped RCS)' : '' ]}'");
like($trap->stderr, qr/^FILTER: \Q$subdir3\E \Q$subdir1\E file2$/m,
	"  log is correct 'FILTER: $subdir3 $subdir1  file2'");

compare_ok($filename5, $filename1, '  destination file 1 is accurate');
file_not_exists_ok($filename6, '  destination file 2 is missing');
SKIP : {
    skip 'rcs not available', 1 unless $have_rcs;
    file_not_exists_ok($rcssubdir2, '  RCS files were not created');
}
