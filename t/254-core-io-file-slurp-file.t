use strict;

use File::Spec;
use File::Temp;
use IO::Handle;
use POSIX qw( :sys_wait_h _exit );
use Test::More tests => 7;
use Test::Trap;
use FindBin;

BEGIN {
    use lib "$FindBin::Bin/../lib";
	use_ok('Conform::Core::IO::File', qw( safe_write_file slurp_file dir_check ))
		or die "# Conform::Core::IO::File not available\n";
}

my $dirname  = File::Temp::tempdir(CLEANUP => 1);
my $filename = File::Spec->catfile($dirname, 'file');

my $content = <<EOF;
line 1
line 2




line 7
line 8
EOF

my $ok = safe_write_file $filename, $content;
ok($ok, 'file prepared')
	or die "# Could not prepare file\n";

############################################################################

my $all = slurp_file $filename;
is($all, $content, 'slurp_file works in scalar context');

my @lines = slurp_file $filename;
is_deeply(\@lines, [ split /(?<=\n)/, $content ], 'slurp_file works in list context');

{
	local $/;
	my @lines = slurp_file $filename;
	is_deeply(\@lines, [ $content ], 'slurp_file works in "slurp" mode');
}

{
	local $/ = '';
	my @lines = slurp_file $filename;
	is_deeply(\@lines, [ $content =~ /(.+?(?:\z|\n\n))\n*/sg ], 'slurp_file works in "paragraph" mode');
}

{
	local $/ = \3;
	my @lines = slurp_file $filename;
	is_deeply(\@lines, [ $content =~ /(.{1,3})/sg ], 'slurp_file works in "record" mode');
}

############################################################################
