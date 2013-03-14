use strict;
use warnings;
use Test::More tests => 41;

use File::Spec;
use File::Temp;
use Test::File;
use Test::Files;
use Test::Trap;
use IO::File;
use FindBin;

BEGIN {
    use lib "$FindBin::Bin/../lib";
    use_ok ('Conform::Core::IO::Command', qw(find_command));
	use_ok ('Conform::Core::IO::File', qw(template_install template_text_install template_file_install text_install))
		or die "# Error importing Conform::Core::IO::File";
}


my $have_rcs = find_command 'ci' && find_command 'co';

my $dir = File::Temp::tempdir(CLEANUP => 1);
my $rcsdir = File::Spec->catdir($dir, "RCS");
my $file1 = File::Spec->catfile($dir, 'file1');
my $file2 = File::Spec->catfile($dir, 'file2');
my $file3 = File::Spec->catfile($dir, 'file3');
my $file4 = File::Spec->catfile($dir, 'file4');

my $tmpl = <<'EOTMPL';
Hello, {$what}!
EOTMPL

my $updated = trap { template_install $file1, \$tmpl, { what => 'SCALAR ref' }, '/bin/echo OK' };

is($trap->die, undef, "template_text_install completed OK with SCALAR ref");
ok ($updated, "file updated");
file_ok($file1, <<EOCONTENT, '  file is created correctly');
Hello, SCALAR ref!
EOCONTENT
SKIP : {
    skip "rcs not available", 1 unless $have_rcs;
    dir_only_contains_ok($rcsdir, ['file1,v'], '  RCS file is created');
}
is ($trap->stderr, <<EOERR, "cmd run OK");
Installing '$file1' from text
@{[$have_rcs ? "Creating directory $rcsdir with mode 700\n" : ""]}Running '/bin/echo OK' to finish install of $file1
EOERR

$updated = trap { template_install $file1, $tmpl, { what => 'SCALAR' }, '/bin/echo OK' };

is($trap->die, undef, "template_install completed OK with SCALAR ref");
ok ($updated, "file updated");
file_ok($file1, <<EOCONTENT, '  file is created correctly');
Hello, SCALAR!
EOCONTENT
is ($trap->stderr, <<EOERR, "cmd run OK");
Installing '$file1' from text
Running '/bin/echo OK' to finish install of $file1
EOERR

$updated = trap { template_install $file1, ["Hello, ", '{$what}!', "\n"], { what => 'ARRAY ref' }, '/bin/echo OK' };

is($trap->die, undef, "template_install completed OK with ARRAY ref");
ok ($updated, "file updated");
file_ok($file1, <<EOCONTENT, '  file is created correctly');
Hello, ARRAY ref!
EOCONTENT
is ($trap->stderr, <<EOERR, "cmd run OK");
Installing '$file1' from text
Running '/bin/echo OK' to finish install of $file1
EOERR

$updated = trap { template_install $file1, sub { 'STRING' => 'Hello, {$what}!' . "\n" } , { what => 'CODE ref' }, '/bin/echo OK' };

is($trap->die, undef, "template_install completed OK with CODE ref");
ok ($updated, "file updated");
file_ok($file1, <<EOCONTENT, '  file is created correctly');
Hello, CODE ref!
EOCONTENT
is ($trap->stderr, <<EOERR, "cmd run OK");
Installing '$file1' from text
Running '/bin/echo OK' to finish install of $file1
EOERR

trap { text_install $file2, <<'EOTMPL'; };
Hello, {$what}!
EOTMPL
ok (-f $file2, "File template created OK");

$updated = trap { template_install $file1, $file2, { what => 'FILE' }, '/bin/echo OK' };

is($trap->die, undef, "template_install completed OK with FILE");
ok ($updated, "file updated");
file_ok($file1, <<EOCONTENT, '  file is created correctly');
Hello, FILE!
EOCONTENT
is ($trap->stderr, <<EOERR, "cmd run OK");
Installing '$file1' from text
Running '/bin/echo OK' to finish install of $file1
EOERR

my $fh = trap { open my $fh, '<', $file2 or die "Error opening file"; $fh; };
ok ($fh, "File $file2 open OK");

$updated = trap { template_install $file1, $fh, { what => 'FILEHANDLE' }, '/bin/echo OK' };

is($trap->die, undef, "template_install completed OK with FILEHANDLE");
ok ($updated, "file updated");
file_ok($file1, <<EOCONTENT, '  file is created correctly');
Hello, FILEHANDLE!
EOCONTENT
is ($trap->stderr, <<EOERR, "cmd run OK");
Installing '$file1' from text
Running '/bin/echo OK' to finish install of $file1
EOERR

$updated = trap { template_text_install $file1, "Hello, {\$what}!\n", { what => 'World' }, '/bin/echo OK' };

is($trap->die, undef, "template_text_install completed OK");
ok ($updated, "file updated");
file_ok($file1, <<EOCONTENT, '  file is created correctly');
Hello, World!
EOCONTENT
is ($trap->stderr, <<EOERR, "cmd run OK");
Installing '$file1' from text
Running '/bin/echo OK' to finish install of $file1
EOERR



trap { text_install $file2, <<'EOTMPL'; };
Test template_file_install {$OK}
{ for (@data) { $OUT .= "DATA $_\n", } }
{i_isa('Env')}
EOTMPL

file_ok($file2,<<EOFILE, 'File template created OK');
Test template_file_install {\$OK}
{ for (\@data) { \$OUT .= "DATA \$_\\n", } }
{i_isa('Env')}
EOFILE

$updated = trap { template_file_install $file3, $file2, { OK => 'OK', data => [1,2,3], i_isa => sub { 'MyEnv' }  } , '/bin/echo OK' };

is($trap->die, undef, "template_file_install completed OK");
ok ($updated, "file updated");
file_ok($file3, <<EOCONTENT,  'file is created correctly');
Test template_file_install OK
DATA 1
DATA 2
DATA 3

MyEnv
EOCONTENT

is ($trap->stderr, <<EOERR, "cmd run OK");
Installing '$file3' from text
Running '/bin/echo OK' to finish install of $file3
EOERR

trap { template_install $file4, "Bad {\$template; somerandomcoderef->()\n}", { }, '/bin/echo NOT OK',  { }; };
like($trap->die, qr/template error line 1: Undefined subroutine &Text::Template::GEN\d+::somerandomcoderef called at template line 1/, "template_install die's correctly");

trap { template_install $file4, "Bad {\$template; somerandomcoderef->()\n\}}", { }, '/bin/echo NOT OK',  { }; };
like($trap->die, qr/Unmatched close brace at line 2/, "template_install die's correctly for unmatched closed braces");

trap { template_install $file4, "Bad {1/0; \$template; somerandomcoderef->()\n}", { }, '/bin/echo NOT OK',  { }; };
like($trap->die, qr/Illegal division by zero/, "template_install die's correctly on assertions");



1;
