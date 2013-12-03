use strict;

use File::Spec;
use File::Temp;
use Test::More tests => 49;
use Test::File;
use Test::Files;
use Test::Trap;
use FindBin;

BEGIN {
    use lib "$FindBin::Bin/../lib";
	use_ok('Conform::Core::IO::File', qw( text_install file_append ))
		or die "# Conform::Core::IO::File not available\n";
}

use Conform::Logger;
Conform::Logger->configure('stderr' => { formatter => { default => '%m' } });


sub find_bin {
    my $bin = shift
            or return undef;
    for my $path (qw(/usr/bin /bin /usr/local/bin)) {
        return "$path/$bin"
            if -x "$path/$bin";
    }
    return undef;
}


my $have_rcs = find_bin 'ci' && find_bin 'co';

my $dirname   = File::Temp::tempdir(CLEANUP => 1);
my $filename1 = File::Spec->catfile($dirname, 'file1');
my $filename2 = File::Spec->catfile($dirname, 'file2');
my $filename3dir = File::Spec->catfile($dirname, int(rand(1000)));
my $filename3 = File::Spec->catfile($filename3dir,'file3');

my $top = <<EOF;
line 1
line 2
EOF
my $line1 = <<EOF;
foo bar baz
EOF
my $line2 = <<EOF;
line replaced
EOF
my $lines = <<EOF;
foo
bar
baz
EOF
my $line3 = 'no newline';
my $lines2 = "foo\nbar\nno newline";

my $updated;

$updated = trap { text_install $filename1, $top };
ok($updated, 'file prepared')
	or die "# Could not prepare file\n";

############################################################################

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { file_append $filename1, $line1, qr/^foo/, '/bin/echo done' };
	ok($updated, 'safe mode: file_append returns true');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Appending '$line1' to $filename1
SKIPPING: Running '/bin/echo done' to finish install of $filename1
EOF
	file_ok($filename1, $top, '  file is untouched');
}

$updated = trap { file_append $filename1, $line1, qr/^foo/, '/bin/echo done' };
ok($updated, 'file_append returns true');
is($trap->stderr, <<EOF, '  log is correct');
Appending '$line1' to $filename1
Running '/bin/echo done' to finish install of $filename1
EOF
file_ok($filename1, "$top$line1", '  file has extra line');

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { file_append $filename1, $line1, qr/^foo/, '/bin/echo done' };
	ok(!$updated, 'safe mode: file_append now returns false');
	is($trap->stderr, <<EOF, '  log is correct');
EOF
	file_ok($filename1, "$top$line1", '  file is untouched');
}

$updated = trap { file_append $filename1, $line1, qr/^foo/, '/bin/echo done' };
ok(!$updated, 'file_append now returns false');
is($trap->stderr, <<EOF, '  log is correct');
EOF
file_ok($filename1, "$top$line1", '  file is untouched');

{
	local $Conform::Core::safe_mode = 1;
	trap { file_append $filename1, $line1, qr/^bad/ };
	ok($trap->die, 'safe mode: file_append croaks on bad regex');
	file_ok($filename1, "$top$line1", '  file is untouched');
}

trap { file_append $filename1, $line1, qr/^bad/ };
ok($trap->die, 'file_append croaks on bad regex');
file_ok($filename1, "$top$line1", '  file is untouched');

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { file_append $filename1, $line2, qr/^line/ };
	ok($updated, 'safe mode: file_append returns true when replacing lines with single line');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Appending '$line2' to $filename1
EOF
	file_ok($filename1, "$top$line1", '  file is untouched');
}

$updated = trap { file_append $filename1, $line2, qr/^line/ };
ok($updated, 'file_append returns true when replacing lines with single line');
is($trap->stderr, <<EOF, '  log is correct');
Appending '$line2' to $filename1
EOF
file_ok($filename1, "$line1$line2", '  file is updated correctly');

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { file_append $filename1, $lines, qr/^f/ };
	ok($updated, 'safe mode: file_append returns true when replacing lines with multiple lines');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Appending '$lines' to $filename1
EOF
	file_ok($filename1, "$line1$line2", '  file is untouched');
}

$updated = trap { file_append $filename1, $lines, qr/^f/ };
ok($updated, 'file_append returns true when replacing lines with multiple lines');
is($trap->stderr, <<EOF, '  log is correct');
Appending '$lines' to $filename1
EOF
file_ok($filename1, "$line2$lines", '  file is updated correctly');

{
	local $Conform::Core::safe_mode = 1;
	trap { file_append $filename2, $line1, qr/^foo/ };
	ok($trap->die, 'safe mode: file_append croaks when file does not exists');
	file_not_exists_ok($filename2, '  file is not created');
}

trap { file_append $filename2, $line1, qr/^foo/ };
ok($trap->die, 'file_append croaks when file does not exists');
file_not_exists_ok($filename2, '  file is not created');

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { file_append $filename2, $line1, qr/^foo/, undef, 1 };
	ok($updated, 'safe mode: file_append returns true when asked to create file');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Appending '$line1' to $filename2 (new file)
EOF
	file_not_exists_ok($filename2, '  file is not created');
}

$updated = trap { file_append $filename2, $line1, qr/^foo/, undef, 1 };
ok($updated, 'file_append returns true when asked to create file');
is($trap->stderr, <<EOF, '  log is correct');
Appending '$line1' to $filename2 (new file)
EOF
file_ok($filename2, $line1, '  file is created correctly');

$updated = trap { file_append $filename2, $line3, qr/^no / };
ok($updated, 'file_append returns true when appending a line with no newline');
is($trap->stderr, <<EOF, '  log is correct');
Appending '$line3
' to $filename2
EOF
file_ok($filename2, "$line1$line3\n", 'correctly added newline when none present in $line');

$updated = trap { file_append $filename2, $lines2, qr/^foo/ };
ok($updated, 'file_append returns true when appending multiple lines with no terminating newline');
is($trap->stderr, <<EOF, '  log is correct');
Appending '$lines2
' to $filename2
EOF
file_ok($filename2, "$line3\n$lines2\n", 'correctly added newline when none present at end of $line');

$updated = trap { file_append $filename3, $line1, qr/^foo/, undef, 1 };
ok($updated, 'file_append returns true when asked to create file and directories');
is($trap->stderr, <<EOF, '  log is correct');
Creating directory $filename3dir with mode 755
Appending '$line1' to $filename3 (new file)@{[$have_rcs ? "\nCreating directory $filename3dir/RCS with mode 700" : "" ]}
EOF
file_ok($filename3, $line1, '  file and directory is created correctly');

