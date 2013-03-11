package Conform::Test::Core::IO::Command;

use warnings;
use strict;

use File::Spec;
use File::Temp;
use POSIX qw( :sys_wait_h SIGALRM SIGTERM SIGKILL );
use Test::File;
use Test::Files;
use Test::More tests => 53;
use Test::Trap;
use FindBin;
use lib "$FindBin::Bin/../lib";

use Conform::Logger;


BEGIN {
	use_ok('Conform::Core::IO::Command', qw( command ))
		or die "# Conform::Core not available\n";
}

my $status;

my $dirname  = File::Temp::tempdir(CLEANUP => 1);
my $stdout   = File::Spec->catfile($dirname, 'stdout');
my $stderr   = File::Spec->catfile($dirname, 'stderr');
my $filename = File::Spec->catfile($dirname, 'filename');

############################################################################

{
	local $Conform::Core::safe_mode = 1;
	$status = trap { command '/bin/echo', 'foo', 'bar', {
		note    => 'note',
		intro   => 'intro',
		success => 'success',
		failure => 'failure',
	} };
	is($status, 0, 'safe mode: command returns 0');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: note
EOF
}

$status = trap { command '/bin/echo', 'foo', 'bar', {
	note    => 'note',
	intro   => 'intro',
	success => 'success',
	failure => 'failure',
} };
is($status, 0, 'command returns 0 for success');
is($trap->stderr, <<EOF, '  log is correct');
note
EOF

{
	local $Conform::Core::safe_mode = 1;
	$status = trap { command '/bin/false', {
		note    => 'note',
		intro   => 'intro',
		success => 'success',
		failure => 'failure',
	} };
	is($status, 0, 'safe mode: unsuccessful command returns 0');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: note
EOF
}

$status = trap { command '/bin/false', {
	note    => 'note',
	intro   => 'intro',
	success => 'success',
	failure => 'failure',
} };
my $code = WEXITSTATUS($status);
ok(WIFEXITED($status) && $code != 0, 'unsuccessful command exits with non-zero exit code');
is($trap->stderr, <<EOF, '  log is correct');
note
failure  Exit code: $code
EOF
#intro
{
	local $Conform::Core::safe_mode = 1;
	$status = trap { command 'kill -ALRM $$' };
	is($status, 0, 'safe mode: killed command returns 0');
	is($trap->stderr, <<EOF, '  log is correct');
EOF
}

my $command = 'kill -ALRM $$';
$status = trap { command $command };
my $sig = WTERMSIG($status);
ok(WIFSIGNALED($status) && $sig == SIGALRM,, 'killed command returns signal number');
is($trap->stderr, <<EOF, '  log is correct');
FAILED: '$command' failed  Signal: @{[SIGALRM]}
EOF

{
	local $Conform::Core::safe_mode = 1;
	$status = trap { command '/does/not/exist' };
	is($status, 0, 'safe mode: non-existent command returns 0');
	is($trap->stderr, <<EOF, '  log is correct');
EOF
}

trap { command '/does/not/exist' };
ok($trap->die, 'non-existent command croaks');

open SAVEOUT, '>&STDOUT'
	or die "# Could not save STDOUT: $!\n";
open SAVEERR, '>&STDERR'
	or die "# Could not save STDERR: $!\n";

sub redirect {
	open STDOUT, ">$stdout"
		or die "# Could not redirect STDOUT: $!\n";
	open STDERR, ">$stderr"
		or die "# Could not redirect STDERR: $!\n";
}

sub unredirect {
	open STDERR, ">&SAVEERR"
		or die "# Could not unredirect STDERR: $!\n";
	open STDOUT, ">&SAVEOUT"
		or die "# Could not unredirect STDOUT: $!\n";
}

{
	local $Conform::Core::safe_mode = 1;
	redirect;
	$status = command 'echo foo; echo bar >&2';
	unredirect;
	is($status, 0, 'safe mode: compound command returns 0');
	file_empty_ok($stdout, '  stdout is correct');
	file_empty_ok($stderr, '  stderr is correct');
}

redirect;
$status = command 'echo foo; echo bar >&2';
unredirect;
is($status, 0, 'compound command returns 0');
file_empty_ok($stdout, '  stdout is correct');
file_ok($stderr, <<EOF, '  stderr is correct');
EOF

{
	local $Conform::Core::safe_mode = 1;
	redirect;
	$status = command 'echo foo; echo bar >&2', { capture => 0 };
	unredirect;
	is($status, 0, 'safe mode: uncaptured compound command returns 0');
	file_empty_ok($stdout, '  stdout is correct');
	file_empty_ok($stderr, '  stderr is correct');
}

redirect;
$status = command 'echo foo; echo bar >&2', { capture => 0 };
unredirect;
is($status, 0, 'uncaptured compound command returns 0');
file_empty_ok($stdout, '  stdout is correct');
file_empty_ok($stderr, '  stderr is correct');

my $capture;
my @capture;

{
	local $Conform::Core::safe_mode = 1;
	redirect;
	$status = command 'echo foo; echo bar >&2', { capture => \$capture };
	unredirect;
	is($status, 0, 'safe mode: captured compound command to \$capture returns 0');
	file_empty_ok($stdout, '  stdout is correct');
	file_empty_ok($stderr, '  stderr is correct');
	is($capture, undef, '  $capture is correct');

	$status = command 'echo foo; echo bar >&2', { capture => \@capture };
	unredirect;
	is($status, 0, 'safe mode: captured compound command to \@capture returns 0');
	file_empty_ok($stdout, '  stdout is correct');
	file_empty_ok($stderr, '  stderr is correct');
	is(scalar @capture, 0, '  $capture is correct');

}

redirect;
$status = command 'echo foo; echo bar >&2', { capture => \$capture };
unredirect;
is($status, 0, 'captured compound command to \$capture returns correct values');
file_empty_ok($stdout, '  stdout is correct');
file_empty_ok($stderr, '  stderr is correct');
is($capture,"foo\nbar\n", '  $capture is correct');

redirect;
$status = command 'echo foo; echo bar >&2', { capture => \@capture };
unredirect;
is($status, 0, 'captured compound command to \@capture returns correct values');
file_empty_ok($stdout, '  stdout is correct');
file_empty_ok($stderr, '  stderr is correct');
is_deeply(\@capture,["foo\n","bar\n"], '  \@capture is correct');

close SAVEOUT;
close SAVEERR;

alarm 10;
$command = "exec 2>/dev/null; echo foo || exit 1; sleep 3; echo bar || exit 2; /bin/touch $filename";
$status = trap { command $command, {
	read_timeout => 1,
} };
$code = WEXITSTATUS($status);
ok(WIFEXITED($status) && $code != 0, 'slow command is timed out');
is($trap->stderr, <<EOF, '  log is correct');
FAILED: '$command' failed  Exit code: 2
EOF
1 while wait != -1;
alarm 0;
file_not_exists_ok($filename, '  pipe is closed');

alarm 10;
$command = 'exec >/dev/null; sleep 5; /bin/touch $filename';
$status = trap { command $command, {
	wait_timeout => 1,
} };
$sig = WTERMSIG($status);
ok(WIFSIGNALED($status) && $sig == SIGTERM, 'slow command that ignores stdout is SIGTERMed');
is($trap->stderr, <<EOF, '  log is correct');
[timeout -- sending SIGTERM]
FAILED: '$command' failed  Signal: @{[SIGTERM]}
EOF
1 while wait != -1;
alarm 0;
file_not_exists_ok($filename, '  child is killed');

alarm 10;
$command = 'trap "" TERM; exec >/dev/null; sleep 5; /bin/touch $filename';
$status = trap { command $command, {
	wait_timeout => 1,
	kill_timeout => 1,
} };
$sig = WTERMSIG($status);
ok(WIFSIGNALED($status) && $sig == SIGKILL, 'slow command that ignores stdout and SIGTERM is SIGKILLed');
is($trap->stderr, <<EOF, '  log is correct');
[timeout -- sending SIGTERM]
[timeout -- sending SIGKILL]
FAILED: '$command' failed  Signal: @{[SIGKILL]}
EOF
1 while wait != -1;
alarm 0;
file_not_exists_ok($filename, '  child is killed');
