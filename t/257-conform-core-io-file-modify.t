#!/usr/bin/perl
# $Id: 110-utils-modify.t,v 1.2 2011/09/06 04:19:06 deanh Exp $

use strict;
use warnings;

use File::Spec;
use File::Temp;
use Test::More tests => 18;
use Test::Files;
use Test::Trap;
use FindBin;

BEGIN {
    use lib "$FindBin::Bin/../lib";
	use_ok('Conform::Core::IO::File', qw( text_install file_modify ))
		or die "# Conform::Core::IO::File not available\n";
}

my $dirname  = File::Temp::tempdir(CLEANUP => 1);
my $filename = File::Spec->catfile($dirname, 'file');

my $updated;

$updated = trap { text_install $filename, <<EOF };
text
EOF
ok($updated, 'file prepared')
	or die "# Could not prepare file\n";

############################################################################

my $foo = 'foo';
use vars qw( $bar );
$bar = 'bar';

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { file_modify $filename, '/bin/echo done', 'tr/a-z/A-Z/', sub { $_ = "${foo}${bar}${_}" } };
	ok($updated, 'safe mode: file_modify returns true');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Modifying $filename
SKIPPING: Running '/bin/echo done' to finish install of $filename
EOF
file_ok($filename, <<EOF, '  file is untouched');
text
EOF
}

$updated = trap { file_modify $filename, '/bin/echo done', 'tr/a-z/A-Z/', sub { $_ = "${foo}${bar}${_}" } };
ok($updated, 'file_modify returns true');
is($trap->stderr, <<EOF, '  log is correct');
Modifying $filename
Running '/bin/echo done' to finish install of $filename
EOF
file_ok($filename, <<EOF, '  file is modified correctly');
foobarTEXT
EOF

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { file_modify $filename, '/bin/echo done', 'tr/z/Z/' };
	ok(!$updated, 'safe mode: file_modify returns false when no changes made');
	is($trap->stderr, <<EOF, '  log is correct');
EOF
file_ok($filename, <<EOF, '  file is untouched');
foobarTEXT
EOF
}

$updated = trap { file_modify $filename, '/bin/echo done', 'tr/z/Z/' };
ok(!$updated, 'file_modify returns false when no changes made');
is($trap->stderr, <<EOF, '  log is correct');
EOF
file_ok($filename, <<EOF, '  file is untouched');
foobarTEXT
EOF

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { file_modify $filename, undef, 'die', sub { $_ == "abc\n" } };
	ok($trap->die, 'safe mode: file_modify croaks when transform dies');
file_ok($filename, <<EOF, '  file is untouched');
foobarTEXT
EOF
}

$updated = trap { file_modify $filename, undef, 'die', sub { $_ == "abc\n" } };
ok($trap->die, 'file_modify croaks when transform dies');
file_ok($filename, <<EOF, '  file is untouched');
foobarTEXT
EOF
