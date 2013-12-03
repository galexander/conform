use strict;
use warnings;

use File::Spec;
use File::Temp;
use Test::More tests => 25;
use Test::File;
use Test::Trap;
use FindBin;

BEGIN {
    use lib "$FindBin::Bin/../lib";
    use_ok('Conform::Core::IO::Command', qw( command ));
	use_ok('Conform::Core::IO::File', qw( symlink_check ))
		or die "# Conform::Core::IO::File not available\n";
}

use Conform::Logger;
Conform::Logger->configure('stderr' => { formatter => { default => '%m' } });

my $dirname   = File::Temp::tempdir(CLEANUP => 1);
my $filename1 = File::Spec->catfile($dirname, 'file1');
my $filename2 = File::Spec->catfile($dirname, 'file2');
my $filename3 = File::Spec->catfile($dirname, 'file3');
my $filename4 = File::Spec->catfile($dirname, 'file4');

my $updated;

my $status = trap { command "/bin/touch $filename1" };
is($status, 0, 'file prepared')
	or die "# Could not prepare file\n";

############################################################################

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { symlink_check $filename1, $filename2 };
	ok($updated, 'safe mode: symlink_check returns true');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Creating symlink $filename2 to $filename1
EOF
	file_not_exists_ok($filename2, '  symlink is not created');
}

$updated = trap { symlink_check $filename1, $filename2 };
ok($updated, 'symlink_check returns true');
is($trap->stderr, <<EOF, '  log is correct');
Creating symlink $filename2 to $filename1
EOF
symlink_target_exists_ok($filename2, $filename1, '  symlink is valid');

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { symlink_check $filename3, $filename4 };
	ok($updated, 'safe mode: symlink_check to missing file returns true');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Creating symlink $filename4 to $filename3
EOF
	file_not_exists_ok($filename4, '  symlink is not created');
}

$updated = trap { symlink_check $filename3, $filename4 };
ok($updated, 'symlink_check to missing file returns true');
is($trap->stderr, <<EOF, '  log is correct');
Creating symlink $filename4 to $filename3
EOF
symlink_target_dangles_ok($filename4, '  symlink is dangling');

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { symlink_check $filename1, $filename4 };
	ok($updated, 'safe mode: symlink_check to new file returns true');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: Changing target of symlink $filename4 to $filename1
EOF
	symlink_target_dangles_ok($filename4, '  symlink is untouched');
}

$updated = trap { symlink_check $filename1, $filename4 };
ok($updated, 'symlink_check to new file returns true');
is($trap->stderr, <<EOF, '  log is correct');
Changing target of symlink $filename4 to $filename1
EOF
symlink_target_exists_ok($filename4, $filename1, '  symlink is now valid');

{
	local $Conform::Core::safe_mode = 1;
	$updated = trap { symlink_check $filename2, $filename1 };
	ok($trap->die, 'safe mode: symlink_check croaks if overwriting non-symlink');
	file_empty_ok($filename1, '  non-symlink is untouched')
}

$updated = trap { symlink_check $filename2, $filename1 };
ok($trap->die, 'symlink_check croaks if overwriting non-symlink');
file_empty_ok($filename1, '  non-symlink is untouched')
