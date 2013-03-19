use strict;
use warnings;

use File::Spec;
use File::Temp;
use Test::More tests => 16;
use Test::File;
use Test::Files;
use Test::Trap;
use FindBin;

BEGIN {
    use lib "$FindBin::Bin/../lib";
    use_ok ('Conform::Core::IO::Command', qw( find_command ));
	use_ok('Conform::Core::IO::File', qw( text_install file_unlink ))
		or die "# Conform::Core::IO::File not available\n";
}

my $have_rcs = find_command 'ci';

my $dirname    = File::Temp::tempdir(CLEANUP => 1);
my $rcsdirname = File::Spec->catdir($dirname, 'RCS');
my $filename   = File::Spec->catfile($dirname, 'file');

my $updated;

$updated = trap { text_install $filename, <<EOF, undef, { rcs => 0 } };
text
EOF
ok($updated, 'file prepared')
	or die "# Could not prepare file\n";
file_not_exists_ok($rcsdirname, '  without RCS file');

############################################################################

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { file_unlink $filename, '/bin/echo done' };
	ok($updated, 'safe mode: file_unlink returns true');
	is($trap->stderr, <<EOF, '  log is correct');
@{[$have_rcs ? "SKIPPING: Creating directory $rcsdirname with mode 700\n" : "" ]}SKIPPING: Unlinking $filename
SKIPPING: Running '/bin/echo done' to finish removal of $filename
EOF
	file_exists_ok($filename, '  file is untouched');
	file_not_exists_ok($rcsdirname, '  RCS file not created');
}

$updated = trap { file_unlink $filename, '/bin/echo done' };
ok($updated, 'safe mode: file_unlink returns true');
is($trap->stderr, <<EOF, '  log is correct');
@{[$have_rcs ? "Creating directory $rcsdirname with mode 700\n" : "" ]}Unlinking $filename
Running '/bin/echo done' to finish removal of $filename
EOF
file_not_exists_ok($filename, '  file is unlinked');
SKIP: {
    skip "rcs not available", 1 unless $have_rcs;
    dir_only_contains_ok($rcsdirname, ['file,v'], '  RCS file is created');
}

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { file_unlink $filename, '/bin/echo done' };
	ok(!$updated, 'safe mode: file_unlink returns false on missing file');
	is($trap->stderr, <<EOF, '  log is correct');
EOF
}

$updated = trap { file_unlink $filename, '/bin/echo done' };
ok(!$updated, 'file_unlink returns false on missing file');
is($trap->stderr, <<EOF, '  log is correct');
EOF
