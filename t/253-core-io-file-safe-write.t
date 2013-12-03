use strict;

use File::Spec;
use File::Temp;
use IO::File;
use Test::More tests => 42;
use Test::File;
use Test::Files;
use Test::Trap;
use FindBin;

BEGIN {
    use lib "$FindBin::Bin/../lib";
    use_ok('Conform::Core::IO', qw( command ));
	use_ok('Conform::Core::IO::File', qw( safe_write_file safe_write ))
		or die "# Conform::Core::IO::File not available\n";
}

Conform::Logger->configure('stderr' => { formatter => { default => '%m' } });

my $mask = umask 0000;

my $dirname    = File::Temp::tempdir(CLEANUP => 1);
my $rcsdirname = File::Spec->catdir($dirname, 'RCS');
my $filename1  = File::Spec->catfile($dirname, 'file1');
my $filename2  = File::Spec->catfile($dirname, 'file2');
my $filename3  = File::Spec->catfile($dirname, 'file3');
my $output     = File::Spec->catfile($dirname, 'output');

my $ok;

############################################################################


{
	local $Conform::Core::safe_mode = 1;
	$ok = trap { safe_write_file $filename1,
		"abc\n", "def\n",
		{ note => 'note' };
	};
	ok($ok, 'safe mode: safe_write_file returns true');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: note
EOF
	file_not_exists_ok($filename1, '  file is not created');
	file_not_exists_ok($rcsdirname, '  RCS file is not created');
}

$ok = trap { safe_write_file $filename1,
	"abc\n", "def\n",
	{ note => 'note' };
};
ok($ok, 'safe_write_file returns true');
is($trap->stderr, <<EOF, '  log is correct');
note
EOF
file_ok($filename1, <<EOF, '  file is created correctly');
abc
def
EOF
file_not_exists_ok($rcsdirname, '  RCS file is not created');
file_mode_is($filename1, 0666, '  file mode is correct');

umask 0244;

{
	local $Conform::Core::safe_mode = 1;
	$ok = trap { safe_write_file $filename1,
		"ghi\n", "jkl\n",
		{ mode => 0640 };
	};
	ok($ok, 'safe mode: safe_write_file returns true');
	is($trap->stderr, <<EOF, '  log is correct');
EOF
	file_ok($filename1, <<EOF, '  file is untouched');
abc
def
EOF
	file_mode_is($filename1, 0666, '  file mode is untouched');
}

$ok = trap { safe_write_file $filename1,
	"ghi\n", "jkl\n",
	{ mode => 0640 };
};
ok($ok, 'safe_write_file returns true');
is($trap->stderr, <<EOF, '  log is correct');
Changing mode of $filename1 to 640
EOF
file_ok($filename1, <<EOF, '  file is overwritten');
ghi
jkl
EOF
file_mode_is($filename1, 0640, '  file mode is updated');

{
	local $Conform::Core::safe_mode = 1;
	$ok = trap { safe_write_file $filename1,
		"mno\n", "pqr\n",
	};
	ok($ok, 'safe mode: safe_write_file returns true');
	is($trap->stderr, <<EOF, '  log is correct');
EOF
	file_ok($filename1, <<EOF, '  file is untouched');
ghi
jkl
EOF
	file_mode_is($filename1, 0640, '  file mode is untouched');
}
$ok = trap { safe_write_file $filename1, "mno\n", "pqr\n", };
ok($ok, 'safe_write_file returns true');
file_ok($filename1, <<EOF, '  file is overwritten');
mno
pqr
EOF
file_mode_is($filename1, 0640, '  file mode is untouched');

umask $mask;

{
	local $Conform::Core::safe_mode = 1;
	$ok = do {
		my $fh = new IO::File($filename1, '<')
			or die "# Could not open $filename1 for reading: $!\n";
		trap { safe_write_file $filename2, $fh };
	};
	ok($ok, 'safe mode: safe_write_file returns true');
	is($trap->stderr, <<EOF, '  log is correct');
EOF
	file_not_exists_ok($filename2, '  file is not created');
}

$ok = do {
	my $fh = new IO::File($filename1, '<')
		or die "# Could not open $filename1 for reading: $!\n";
	trap { safe_write_file $filename2, $fh };
};
ok($ok, 'safe_write_file returns true');
is($trap->stderr, <<EOF, '  log is correct');
EOF
compare_ok($filename2, $filename1, '  file is created correctly');

############################################################################

{
	local $Conform::Core::safe_mode = 1;
	$ok = trap { safe_write $filename3,
		"123\n", "456\n",
		{ note => 'note' };
	};
	ok($ok, 'safe mode: safe_write returns true');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: note
EOF
	file_not_exists_ok($filename3, '  file is not created');
	file_not_exists_ok($rcsdirname, '  RCS file not created');
}

SKIP: {
    skip '/usr/bin/ci not available', 4 unless -x '/usr/bin/ci';
    $ok = trap { safe_write $filename3,
    	"123\n", "456\n",
    	{ note => 'note' };
    };
    ok($ok, 'safe mode: safe_write returns true');
    is($trap->stderr, <<EOF, '  log is correct');
note
Creating directory $rcsdirname with mode 700
EOF
    file_ok($filename3, <<EOF, '  file is created correctly');
123
456
EOF
    dir_only_contains_ok($rcsdirname, ['file3,v'], '  RCS file is created correctly');
}

SKIP: {
	skip '/usr/bin/co not available', 2 unless -x '/usr/bin/co';
	my $status = command "/usr/bin/co -p $filename3 >$output 2>/dev/null";
	is($status, 0, 'RCS checkout is successful');
	compare_ok($filename3, $output, '  file is same as original');
}
