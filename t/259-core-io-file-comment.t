use strict;
use warnings;

use File::Spec;
use File::Temp;
use Test::More tests => 56;
use Test::Files;
use Test::Trap;
use FindBin;

BEGIN {
    use lib "$FindBin::Bin/../lib";
	use_ok('Conform::Core::IO::File', qw(
		text_install
		file_comment_spec file_uncomment_spec
		file_comment file_uncomment
	)) or die "# Conform::Core::IO::File not available\n";
}

my $dirname  = File::Temp::tempdir(CLEANUP => 1);
my $filename = File::Spec->catfile($dirname, 'file');

my $updated;

$updated = trap { text_install $filename, <<EOF };
aaa
bbb
aaa
bbb
EOF
ok($updated, 'file prepared')
	or die "# Could not prepare file\n";

############################################################################

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { file_comment_spec $filename, '%', '/bin/echo done', qr/^a/ };
	ok($updated, 'safe mode: file_comment_spec returns true');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Modifying $filename
SKIPPING: Running '/bin/echo done' to finish install of $filename
EOF
	file_ok($filename, <<EOF, '  file is untouched');
aaa
bbb
aaa
bbb
EOF
}

$updated = trap { file_comment_spec $filename, '%', '/bin/echo done', qr/^a/ };
ok($updated, 'file_comment_spec returns true');
is($trap->stderr, <<EOF, '  log is correct');
Modifying $filename
Running '/bin/echo done' to finish install of $filename
EOF
file_ok($filename, <<EOF, '  file is commented correctly');
%aaa
bbb
%aaa
bbb
EOF

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { file_comment_spec $filename, '%', '/bin/echo done', qr/^a/ };
	ok(!$updated, 'safe mode: file_comment_spec returns false when no changes made');
	is($trap->stderr, <<EOF, '  log is correct');
EOF
	file_ok($filename, <<EOF, '  file is untouched');
%aaa
bbb
%aaa
bbb
EOF
}

$updated = trap { file_comment_spec $filename, '%', '/bin/echo done', qr/^a/ };
ok(!$updated, 'file_comment_spec returns false when no changes made');
is($trap->stderr, <<EOF, '  log is correct');
EOF
file_ok($filename, <<EOF, '  file is untouched');
%aaa
bbb
%aaa
bbb
EOF

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { file_uncomment_spec $filename, '%', '/bin/echo done', qr/^a/ };
	ok($updated, 'safe mode: file_uncomment_spec returns true');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Modifying $filename
SKIPPING: Running '/bin/echo done' to finish install of $filename
EOF
	file_ok($filename, <<EOF, '  file is untouched');
%aaa
bbb
%aaa
bbb
EOF
}

$updated = trap { file_uncomment_spec $filename, '%', '/bin/echo done', qr/^a/ };
ok($updated, 'file_uncomment_spec returns true');
is($trap->stderr, <<EOF, '  log is correct');
Modifying $filename
Running '/bin/echo done' to finish install of $filename
EOF
file_ok($filename, <<EOF, '  file is commented correctly');
aaa
bbb
aaa
bbb
EOF

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { file_uncomment_spec $filename, '%', '/bin/echo done', qr/^a/ };
	ok(!$updated, 'safe mode: file_uncomment_spec returns false when no changes made');
	is($trap->stderr, <<EOF, '  log is correct');
EOF
	file_ok($filename, <<EOF, '  file is untouched');
aaa
bbb
aaa
bbb
EOF
}

$updated = trap { file_uncomment_spec $filename, '%', '/bin/echo done', qr/^a/ };
ok(!$updated, 'file_uncomment_spec returns false when no changes made');
is($trap->stderr, <<EOF, '  log is correct');
EOF
file_ok($filename, <<EOF, '  file is untouched');
aaa
bbb
aaa
bbb
EOF

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { file_uncomment_spec $filename, qr/^../, '/bin/echo done', qr/^a/ };
	ok($updated, 'safe mode: file_uncomment_spec returns true with a regex comment');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Modifying $filename
SKIPPING: Running '/bin/echo done' to finish install of $filename
EOF
	file_ok($filename, <<EOF, '  file is untouched');
aaa
bbb
aaa
bbb
EOF
}

$updated = trap { file_uncomment_spec $filename, qr/^../, '/bin/echo done', qr/^a/ };
ok($updated, 'file_uncomment_spec returns true with a regex comment');
is($trap->stderr, <<EOF, '  log is correct');
Modifying $filename
Running '/bin/echo done' to finish install of $filename
EOF
file_ok($filename, <<EOF, '  file is commented correctly');
a
bbb
a
bbb
EOF

############################################################################

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { file_comment $filename, '/bin/echo done', qr/^b/ };
	ok($updated, 'safe mode: file_comment returns true');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Modifying $filename
SKIPPING: Running '/bin/echo done' to finish install of $filename
EOF
	file_ok($filename, <<EOF, '  file is untouched');
a
bbb
a
bbb
EOF
}

$updated = trap { file_comment $filename, '/bin/echo done', qr/^b/ };
ok($updated, 'file_comment returns true');
is($trap->stderr, <<EOF, '  log is correct');
Modifying $filename
Running '/bin/echo done' to finish install of $filename
EOF
file_ok($filename, <<EOF, '  file is commented correctly');
a
#bbb
a
#bbb
EOF

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { file_comment $filename, '/bin/echo done', qr/^b/ };
	ok(!$updated, 'safe mode: file_comment returns false when no changes made');
	is($trap->stderr, <<EOF, '  log is correct');
EOF
	file_ok($filename, <<EOF, '  file is untouched');
a
#bbb
a
#bbb
EOF
}

$updated = trap { file_comment $filename, '/bin/echo done', qr/^b/ };
ok(!$updated, 'file_comment returns false when no changes made');
is($trap->stderr, <<EOF, '  log is correct');
EOF
file_ok($filename, <<EOF, '  file is untouched');
a
#bbb
a
#bbb
EOF

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { file_uncomment $filename, '/bin/echo done', qr/^b/ };
	ok($updated, 'safe mode: file_uncomment returns true');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Modifying $filename
SKIPPING: Running '/bin/echo done' to finish install of $filename
EOF
	file_ok($filename, <<EOF, '  file is untouched');
a
#bbb
a
#bbb
EOF
}

$updated = trap { file_uncomment $filename, '/bin/echo done', qr/^b/ };
ok($updated, 'file_uncomment returns true');
is($trap->stderr, <<EOF, '  log is correct');
Modifying $filename
Running '/bin/echo done' to finish install of $filename
EOF
file_ok($filename, <<EOF, '  file is commented correctly');
a
bbb
a
bbb
EOF

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { file_uncomment $filename, '/bin/echo done', qr/^b/ };
	ok(!$updated, 'safe mode: file_uncomment returns false when no changes made');
	is($trap->stderr, <<EOF, '  log is correct');
EOF
	file_ok($filename, <<EOF, '  file is untouched');
a
bbb
a
bbb
EOF
}

$updated = trap { file_uncomment $filename, '/bin/echo done', qr/^b/ };
ok(!$updated, 'file_uncomment returns false when no changes made');
is($trap->stderr, <<EOF, '  log is correct');
EOF
file_ok($filename, <<EOF, '  file is untouched');
a
bbb
a
bbb
EOF
