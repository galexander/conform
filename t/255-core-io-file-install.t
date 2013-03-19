use strict;
use warnings;

use File::Spec;
use File::Temp;
use IO::Handle;
use POSIX qw( :sys_wait_h _exit );
use Test::More tests => 117;
use Test::File;
use Test::Files;
use Test::Trap;
use FindBin;

BEGIN {
    use lib "$FindBin::Bin/../lib";
	use_ok('Conform::Core::IO::File', qw( text_install file_install ))
		or die "# Conform::Core::IO::File not available\n";
}

sub _filter_rcs_id { # added on sirz 52319
    return join '', map {
            my $foo = $_;
            $foo =~ s/\$Id.*\$/\$Id\$/g;
            $foo =~ s/\$Revision.*\$/\$Revision\$/g;
            $foo } @_
}

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

my $dirname       = File::Temp::tempdir(CLEANUP => 1);
my $rcsdirname    = File::Spec->catdir($dirname, 'RCS');
my $filename1     = File::Spec->catfile($dirname, 'file1');
my $filename2     = File::Spec->catfile($dirname, 'file2');
my $subdir        = File::Spec->catdir($dirname, 'subdir');
my $rcssubdirname = File::Spec->catdir($subdir, 'RCS');
my $filename3     = File::Spec->catfile($subdir, 'file3');
my $filename4     = File::Spec->catfile($dirname, 'file4');
my $filename5     = File::Spec->catfile($dirname, 'file5');

my $content = <<'EOF';
foo bar baz
123 456 789
EOF

# break this up so that when we check in the test, this wont be updated
my $rcscontent = $content;
$rcscontent .= '# $' . 'Id: Conform.pm,v 1.45 2011/09/09 07:05:45 deanh Exp $' ."\n";
$rcscontent .= '$VERSION = (qw$' . 'Revision: 1.8 $)[1];'."\n";

(my $other = $content) =~ tr/ab/xy/;
(my $rcsother = $rcscontent) =~ tr/ab/xy/;

my $updated;

########################################################################
## text_install returns true

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { text_install $filename1, $content, '/bin/echo done' };
	ok($updated, 'safe mode: text_install returns true');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Installing '$filename1' from text
SKIPPING: Running '/bin/echo done' to finish install of $filename1
EOF
	file_not_exists_ok($filename1, '  file is not created');
	file_not_exists_ok($rcsdirname, '  RCS file is not created');

	$updated = trap { text_install $filename1.'rcsid', $rcscontent, '/bin/echo done' };
	ok($updated, 'safe mode: text_install returns true with $Id: 108-utils-install.t,v 1.5 2011/09/12 06:01:00 deanh Exp $ tags');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Installing '${filename1}rcsid' from text
SKIPPING: Running '/bin/echo done' to finish install of ${filename1}rcsid
EOF
	file_not_exists_ok($filename1.'rcsid', '  file is not created');
	file_not_exists_ok($rcsdirname, '  RCS file is not created');
}

$updated = trap { text_install $filename1, $content, '/bin/echo done' };
ok($updated, 'text_install returns true');

is($trap->stderr, <<EOF, '  log is correct');
Installing '$filename1' from text
@{[$have_rcs ? "Creating directory $rcsdirname with mode 700\n" : "" ]}Running '/bin/echo done' to finish install of $filename1
EOF
file_ok($filename1, $content, '  file is created correctly');
SKIP: {
    skip 'rcs not available', 1 unless $have_rcs;
    dir_only_contains_ok($rcsdirname, ['file1,v'], '  RCS file is created');
}
$updated = trap { text_install $filename1.'rcsid', $rcscontent, '/bin/echo done' };
ok($updated, 'text_install returns true with $Id: 108-utils-install.t,v 1.5 2011/09/12 06:01:00 deanh Exp $ tags');
is($trap->stderr, <<EOF, '  log is correct');
Installing '${filename1}rcsid' from text
Running '/bin/echo done' to finish install of ${filename1}rcsid
EOF
    file_filter_ok($filename1.'rcsid', _filter_rcs_id($rcscontent), \&_filter_rcs_id, '  file is created correctly with $Id: 108-utils-install.t,v 1.5 2011/09/12 06:01:00 deanh Exp $ tags');
SKIP: {
    skip 'rcs not available', 1 unless $have_rcs;
    dir_only_contains_ok($rcsdirname, ['file1,v','file1rcsid,v'], '  RCS file is created');
}

########################################################################
## text_install returns false

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { text_install $filename1, $content, '/bin/echo done' };
	ok(!$updated, 'safe mode: text_install now returns false');
	is($trap->stderr, <<EOF, '  log is correct');
EOF
	file_ok($filename1, $content, '  file is untouched');

	$updated = trap { text_install $filename1.'rcsid', $rcscontent, '/bin/echo done' };
	ok(!$updated, 'safe mode: text_install now returns false with $Id: 108-utils-install.t,v 1.5 2011/09/12 06:01:00 deanh Exp $ tags');
	is($trap->stderr, <<EOF, '  log is correct');
EOF
	file_filter_ok($filename1.'rcsid', _filter_rcs_id($rcscontent), \&_filter_rcs_id, '  file is untouched');
}

$updated = trap { text_install $filename1, $content, '/bin/echo done' };
ok(!$updated, 'text_install now returns false');
is($trap->stderr, <<EOF, '  log is correct');
EOF
file_ok($filename1, $content, '  file is untouched');
SKIP: {
    skip 'rcs not available', 1 unless $have_rcs;
    dir_only_contains_ok($rcsdirname, ['file1,v','file1rcsid,v'], '  RCS file is the same');
}

$updated = trap { text_install $filename1 .'rcsid', $rcscontent, '/bin/echo done' };
ok(!$updated, 'text_install now returns false with $Id: 108-utils-install.t,v 1.5 2011/09/12 06:01:00 deanh Exp $ tags');
is($trap->stderr, <<EOF, '  log is correct');
EOF
file_ok($filename1, $content, '  file is untouched');
SKIP: {
    skip 'rcs not available', 1 unless $have_rcs;
    dir_only_contains_ok($rcsdirname, ['file1,v','file1rcsid,v'], '  RCS file is the same');
}

########################################################################
## text_install returns true when skipping RCS

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { text_install $filename2, $content, undef, { rcs => 0 } };
	ok($updated, 'safe mode: text_install returns true when skipping RCS');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Installing '$filename2' from text@{[$have_rcs ? " (skipped RCS)" : ""]}
EOF
	file_not_exists_ok($filename2, '  file is not created');
    SKIP: {
        skip 'rcs not available', 1 unless $have_rcs;
	    dir_only_contains_ok($rcsdirname, ['file1,v','file1rcsid,v'], '  no extra RCS file is created');
    }

	$updated = trap { text_install $filename2.'rcsid', $rcscontent, undef, { rcs => 0 } };
	ok($updated, 'safe mode: text_install returns true when skipping RCS with $Id: 108-utils-install.t,v 1.5 2011/09/12 06:01:00 deanh Exp $ tag');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Installing '${filename2}rcsid' from text@{[$have_rcs ? " (skipped RCS)" : "" ]}
EOF
	file_not_exists_ok($filename2.'rcsid', '  file is not created');
    SKIP: {
        skip 'rcs not available', 1 unless $have_rcs;
	    dir_only_contains_ok($rcsdirname, ['file1,v','file1rcsid,v'], '  no extra RCS file is created');
    }

}

$updated = trap { text_install $filename2, $content, undef, { rcs => 0 } };
ok($updated, 'text_install returns true when skipping RCS');
is($trap->stderr, <<EOF, '  log is correct');
Installing '$filename2' from text@{[$have_rcs ? " (skipped RCS)" : "" ]}
EOF
file_ok($filename2, $content, '  file is created correctly');
SKIP: {
    skip 'rcs not available', 1 unless $have_rcs;
    dir_only_contains_ok($rcsdirname, ['file1,v','file1rcsid,v'], '  no extra RCS file is created');
}

$updated = trap { text_install $filename2.'rcsid', $rcscontent, undef, { rcs => 0 } };
ok($updated, 'text_install returns true when skipping RCS with $Id: 108-utils-install.t,v 1.5 2011/09/12 06:01:00 deanh Exp $ tag');
is($trap->stderr, <<EOF, '  log is correct');
Installing '${filename2}rcsid' from text@{[$have_rcs ? " (skipped RCS)" : ""]}
EOF
file_ok($filename2.'rcsid', $rcscontent, '  file is created correctly');
SKIP: {
    skip 'rcs not available', 1 unless $have_rcs;
    dir_only_contains_ok($rcsdirname, ['file1,v','file1rcsid,v'], '  no extra RCS file is created');
}


########################################################################
## text_install returns true when changing content and with odd srcfn

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { text_install $filename2, '', undef, { srcfn => 'empty string' } };
	ok($updated, 'safe mode: text_install returns true when changing content and with odd srcfn');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Installing '$filename2' from empty string
EOF
	file_ok($filename2, $content, '  file is untouched');
    SKIP: {
        skip 'rcs not available', 1 unless $have_rcs;
	    dir_only_contains_ok($rcsdirname, ['file1,v','file1rcsid,v'], '  no extra RCS file is created');
    }
}

$updated = trap { text_install $filename2, '', undef, { srcfn => 'empty string' } };
ok($updated, 'text_install returns true when changing content and with odd srcfn');
is($trap->stderr, <<EOF, '  log is correct');
Installing '$filename2' from empty string
EOF
file_ok($filename2, '', '  file is updated correctly');
SKIP: {
    skip 'rcs not available', 1 unless $have_rcs;
    dir_contains_ok($rcsdirname, ['file2,v'], '  RCS file is created correctly');
}

########################################################################
## text_install returns true with nested dirs and odd file mode

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { text_install $filename3, $content, undef, { mode => 0000 } };
	ok($updated, 'safe mode: text_install returns true with nested dirs and odd file mode');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Creating directory $subdir with mode 755
SKIPPING: Installing '$filename3' from text
EOF
	file_not_exists_ok($filename3, '  file is not created');
	file_not_exists_ok($rcssubdirname, '  RCS file is not created');

	$updated = trap { text_install $filename3.'rcsid', $rcscontent, undef, { mode => 0000 } };
	ok($updated, 'safe mode: text_install returns true with nested dirs and odd file mode with $Id: 108-utils-install.t,v 1.5 2011/09/12 06:01:00 deanh Exp $ tags');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Creating directory $subdir with mode 755
SKIPPING: Installing '${filename3}rcsid' from text
EOF
	file_not_exists_ok($filename3.'rcsid', '  file is not created');
	file_not_exists_ok($rcssubdirname, '  RCS file is not created');
}

$updated = trap { text_install $filename3, $content, undef, { mode => 0400 } };
ok($updated, 'text_install returns true with nested dirs and odd file mode');
is($trap->stderr, <<EOF, '  log is correct');
Creating directory $subdir with mode 755
Installing '$filename3' from text
@{[$have_rcs ? "Creating directory $rcssubdirname with mode 700\n" : "Changing mode of $filename3 to 400"]}
EOF
file_ok($filename3, $content, '  file is created correctly');
file_mode_is($filename3, 0400, '  file mode is correct');
SKIP: {
    skip 'rcs not available', 1 unless $have_rcs;
    dir_only_contains_ok($rcssubdirname, ['file3,v'], '  RCS file is created correctly');
}


$updated = trap { text_install $filename3.'rcsid', $rcscontent, undef, { mode => 0400 } };
ok($updated, 'text_install returns true with nested dirs and odd file mode with $Id: 108-utils-install.t,v 1.5 2011/09/12 06:01:00 deanh Exp $ tag');
is($trap->stderr, <<EOF, '  log is correct');
Installing '${filename3}rcsid' from text
Changing mode of ${filename3}rcsid to 400
EOF
file_filter_ok($filename3.'rcsid', _filter_rcs_id($rcscontent), \&_filter_rcs_id, '  file is created correctly');
file_mode_is($filename3, 0400, '  file mode is correct');
SKIP: {
    skip 'rcs not available', 1 unless $have_rcs;
    dir_only_contains_ok($rcssubdirname, ['file3,v','file3rcsid,v'], '  RCS file is created correctly');
}

########################################################################
## file_install is successful

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { file_install $filename4, $filename1, '/bin/echo done' };
	ok($updated, 'safe mode: file_install is successful');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Installing '$filename4' from $filename1
SKIPPING: Running '/bin/echo done' to finish install of $filename4
EOF
	file_not_exists_ok($filename4, '  file is not created');
    SKIP: {
        skip 'rcs not available', 1 unless $have_rcs;
	    dir_only_contains_ok($rcsdirname, ['file1,v', 'file1rcsid,v', 'file2,v'], '  RCS file is not created');
    }

	$updated = trap { file_install $filename4.'rcsid', $filename1.'rcsid', '/bin/echo done' };
	ok($updated, 'safe mode: file_install is successful with $Id: 108-utils-install.t,v 1.5 2011/09/12 06:01:00 deanh Exp $ tags');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Installing '${filename4}rcsid' from ${filename1}rcsid
SKIPPING: Running '/bin/echo done' to finish install of ${filename4}rcsid
EOF
	file_not_exists_ok($filename4.'rcsid', '  file is not created');
    SKIP: {
        skip 'rcs not available', 1 unless $have_rcs;
	    dir_only_contains_ok($rcsdirname, ['file1,v', 'file1rcsid,v', 'file2,v'], '  RCS file is not created');
    }

}

$updated = trap { file_install $filename4, $filename1, '/bin/echo done' };
ok($updated, 'file_install is successful');
is($trap->stderr, <<EOF, '  log is correct');
Installing '$filename4' from $filename1
Running '/bin/echo done' to finish install of $filename4
EOF
compare_ok($filename1, $filename4, '  file is created correctly');
SKIP: {
    skip 'rcs not available', 1 unless $have_rcs;
    dir_contains_ok($rcsdirname, ['file4,v'], '  RCS file is created correctly');
}

$updated = trap { file_install $filename4.'rcsid', $filename1.'rcsid', '/bin/echo done' };
ok($updated, 'file_install is successful with $Id: 108-utils-install.t,v 1.5 2011/09/12 06:01:00 deanh Exp $ tags');
is($trap->stderr, <<EOF, '  log is correct');
Installing '${filename4}rcsid' from ${filename1}rcsid
Running '/bin/echo done' to finish install of ${filename4}rcsid
EOF
compare_filter_ok($filename1.'rcsid', $filename4.'rcsid', \&_filter_rcs_id,'  file is created correctly');
SKIP: {
    skip 'rcs not available', 1 unless $have_rcs;
    dir_contains_ok($rcsdirname, ['file4,v', 'file4rcsid,v'], '  RCS file is created correctly');
}

########################################################################
## file_install now returns false

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { file_install $filename4, $filename1, '/bin/echo done' };
	ok(!$updated, 'safe mode: file_install now returns false');
	is($trap->stderr, <<EOF, '  log is correct');
EOF
	compare_ok($filename1, $filename4, '  file is untouched');

	$updated = trap { file_install $filename4.'rcsid', $filename1.'rcsid', '/bin/echo done' };
	ok(!$updated, 'safe mode: file_install now returns false with $Id: 108-utils-install.t,v 1.5 2011/09/12 06:01:00 deanh Exp $ tags');
	is($trap->stderr, <<EOF, '  log is correct');
EOF
	compare_filter_ok($filename1.'rcsid', $filename4.'rcsid', \&_filter_rcs_id,'  file is untouched');
}

$updated = trap { file_install $filename4, $filename1, '/bin/echo done' };
ok(!$updated, 'file_install now returns false');
is($trap->stderr, <<EOF, '  log is correct');
EOF
compare_ok($filename1, $filename4, '  file is untouched');

$updated = trap { file_install $filename4.'rcsid', $filename1.'rcsid', '/bin/echo done' };
ok(!$updated, 'file_install now returns false with $Id: 108-utils-install.t,v 1.5 2011/09/12 06:01:00 deanh Exp $ tags');
is($trap->stderr, <<EOF, '  log is correct');
EOF
compare_filter_ok($filename1.'rcsid', $filename4.'rcsid', \&_filter_rcs_id,'  file is untouched');

########################################################################
## file_install returns true when skipping RCS and transforming

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { file_install $filename5, $filename1, undef, { rcs => 0 }, 's/a/x/g', sub { s/b/y/g } };
	ok($updated, 'safe mode: file_install returns true when skipping RCS and transforming');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Installing '$filename5' from $filename1@{[$have_rcs ? " (skipped RCS)" : ""]}
EOF
	file_not_exists_ok($filename5, '  file is not created');
    SKIP: {
        skip 'rcs not available', 1 unless $have_rcs;
	    dir_only_contains_ok($rcsdirname, ['file1,v', 'file1rcsid,v', 'file2,v', 'file4,v', 'file4rcsid,v'], '  RCS file is not created');
    }

	$updated = trap { file_install $filename5.'rcsid', $filename1.'rcsid', undef, { rcs => 0 }, 's/a/x/g', sub { s/b/y/g } };
	ok($updated, 'safe mode: file_install returns true when skipping RCS and transforming with $Id: 108-utils-install.t,v 1.5 2011/09/12 06:01:00 deanh Exp $ tags');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Installing '${filename5}rcsid' from ${filename1}rcsid@{[$have_rcs ? " (skipped RCS)" : ""]}
EOF
	file_not_exists_ok($filename5.'rcsid', '  file is not created');
    SKIP: {
        skip 'rcs not available', 1 unless $have_rcs;
	    dir_only_contains_ok($rcsdirname, ['file1,v', 'file1rcsid,v', 'file2,v', 'file4,v', 'file4rcsid,v'], '  RCS file is not created');
    }
}

$updated = trap { file_install $filename5, $filename1, undef, { rcs => 0 }, 's/a/x/g', sub { s/b/y/g } };
ok($updated, 'file_install returns true when skipping RCS and transforming');
is($trap->stderr, <<EOF, '  log is correct');
Installing '$filename5' from $filename1@{[$have_rcs ? " (skipped RCS)" : ""]}
EOF
file_ok($filename5, $other, '  file is created correctly');
SKIP: {
    skip 'rcs not available', 1 unless $have_rcs;
    dir_only_contains_ok($rcsdirname, ['file1,v', 'file1rcsid,v', 'file2,v', 'file4,v', 'file4rcsid,v'], '  RCS file is not created');
}

$updated = trap { file_install $filename5.'rcsid', $filename1.'rcsid', undef, { rcs => 0 }, 's/a/x/g', sub { s/b/y/g } };
ok($updated, 'file_install returns true when skipping RCS and transforming with $Id: 108-utils-install.t,v 1.5 2011/09/12 06:01:00 deanh Exp $ tags');
is($trap->stderr, <<EOF, '  log is correct');
Installing '${filename5}rcsid' from ${filename1}rcsid@{[$have_rcs ? " (skipped RCS)" : ""]}
EOF
SKIP: {
    skip 'rcs not available', 2 unless $have_rcs;
    file_filter_ok($filename5.'rcsid', _filter_rcs_id($rcsother), \&_filter_rcs_id, '  file is created correctly');
    dir_only_contains_ok($rcsdirname, ['file1,v', 'file1rcsid,v', 'file2,v', 'file4,v', 'file4rcsid,v'], '  RCS file is not created');
}
