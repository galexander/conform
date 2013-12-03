use strict;

use Test::More tests => 26;
use Test::File;
use Test::Files;
use Test::Trap;
use File::Temp;
use File::Spec;
use FindBin;

BEGIN {
    use lib "$FindBin::Bin/../lib";
    use_ok ('Conform::Core::IO::Command', qw( find_command ));
	use_ok ('Conform::Core::IO::File', 'text_install', 'dir_list')
		or die "# Conform::Core::IO::File qw(text_install dir_list) not available";
}

use Conform::Logger;
Conform::Logger->configure('stderr' => { formatter => { default => '%m' } });

my $dirname = File::Temp::tempdir(CLEANUP => 1);
my $filename1 = File::Spec->catfile($dirname, 'file1');
my $filename2 = File::Spec->catfile($dirname, 'file2');
my $filename3 = File::Spec->catfile($dirname, 'file3');
my $subdir1 = File::Spec->catdir($dirname, 'subdir1');
my $subdir1_filename1 = File::Spec->catfile($subdir1, 'file1');
my $subdir1_filename2 = File::Spec->catfile($subdir1, 'file2');
my $subdir1_filename3 = File::Spec->catfile($subdir1, 'file3');

my $have_rcs = find_command 'ci' && find_command 'co';

######################################################################

is_deeply([dir_list $dirname], [], "dir_list for '\$dirname' is empty");

trap {
	text_install $filename1, 'file1';
	text_install $filename2, 'file2';
	text_install $filename3, 'file3';
	text_install $subdir1_filename1, 'file1';
	text_install $subdir1_filename2, 'file2';
	text_install $subdir1_filename3, 'file3';
};

is ($trap->stderr, <<EOF, '   test data prepared OK according to log');
Installing '$filename1' from text
@{[$have_rcs ? "Creating directory $dirname/RCS with mode 700\n" : "Installing '$filename2' from text" ]}
Installing '$filename3' from text
Creating directory $subdir1 with mode 755
Installing '$subdir1_filename1' from text
@{[$have_rcs ? "Creating directory $subdir1/RCS with mode 700\n" : "Installing '$subdir1_filename2' from text" ]}
Installing '$subdir1_filename3' from text
EOF

dir_only_contains_ok($dirname,
    [ grep { $have_rcs ? 1 : !m{RCS} }
	('file1', 'file2', 'file3', 'RCS', 'subdir1',
	 'RCS/file1,v', 'RCS/file2,v', 'RCS/file3,v',
	 'subdir1/file1', 'subdir1/file2', 'subdir1/file3', 'subdir1/RCS',
	 'subdir1/RCS/file1,v', 'subdir1/RCS/file2,v', 'subdir1/RCS/file3,v',
	)], '   test data prepared OK according to filesystem');

trap { dir_list "$filename1" };
ok($trap->die, "dir_list dies if not supplied a valid directory");

trap { dir_list "$dirname", { include => [] } };
ok($trap->die, "dir_list dies if not supplied a valid include specification");

trap { dir_list "$dirname", { exclude => [] } };
ok($trap->die, "dir_list dies if not supplied a valid exclude specification");

my %list = map (($_ => 1), dir_list $dirname);
ok($list{'subdir1/'} && ( $have_rcs ? $list{'RCS/'} : 1 ), "dir_list correctly appends '/' for directories");

SKIP : {
    skip "rcs not avaiable", 5 unless $have_rcs;
    is_deeply(
        [sort(dir_list($dirname))],
        [grep { $have_rcs ? 1 : !m{RCS} } sort(qw(file1 file2 file3 subdir1/ RCS/))],
    "dir_list correct for unqualified listing");

    is_deeply(
        [sort (dir_list($dirname, { include => qr/RCS/ } ))],
        ['RCS/'],
    "dir_list correct for explicit Regexp include 'qr/RCS/' ");

    is_deeply(
        [sort (dir_list($dirname, { include => qr/RCS/ } ))],
        ['RCS/'],
    "dir_list correct for implicit Regexp include 'RCS' ");

    is_deeply(
        [sort (dir_list($dirname, { include => sub { return 1 if $_[2] eq 'RCS/'  } } ))],
        ['RCS/'],
    "dir_list correct for explicit 'sub' include");
}

is_deeply(
	[sort(dir_list($dirname, { include => qr/file\d+$/ } ))],
	[sort(qw(file1 file2 file3))],
"dir_list correct for include=>'file\\d+\$'");

is_deeply(
	[sort(dir_list($dirname,  { exclude => qr/(RCS|file1)/ } ))],
	[sort(qw(file2 file3 subdir1/))],
"dir_list correct for exclude=>'(RCS|file1)'");

is_deeply(
	[sort(dir_list($dirname, { include => qr/file2/, exclude => qr/file/ }))],
	[sort('file2') ],
"dir_list correct for include=>'qr/file2/',exclude=>'qr/file/'");

is_deeply(
	[sort(dir_list($dirname, { include => qr/file(2|3)/, exclude => qr/file2/, filter_order => 'include,exclude' }))],
	[sort(qw(file2 file3))],
"dir_list correct for include qr'/file2/',exclude=>'qr/file/',filter_order=>'include,exclude'");

is_deeply(
	[sort(dir_list($dirname, { include => qr/file(2|3)/, exclude => qr/file2/, filter_order => 'exclude,include' }))],
	['file3'],
"dir_list correct for include=>'qr/file2/',exclude=>'qr/file/',filter_order=>'exclude,include'");

is_deeply(
	[sort(dir_list($dirname, { recurse => 1 }))],
	[grep { $have_rcs ? 1 : !m{RCS} } sort(qw(file1 file2 file3 RCS/ subdir1/),
	 	'RCS/file1,v', 'RCS/file2,v', 'RCS/file3,v',
	 	qw(subdir1/file1 subdir1/file2 subdir1/file3 subdir1/RCS/),
	 	'subdir1/RCS/file1,v', 'subdir1/RCS/file2,v', 'subdir1/RCS/file3,v')],
"dir_list correct for recurse=>'1'");

is_deeply(
	[sort(dir_list($dirname, { include => qr/,v$/, recurse_first => 1 }))],
	[grep { $have_rcs ? 1 : !m{RCS} } sort('RCS/file1,v', 'RCS/file2,v', 'RCS/file3,v',
		  'subdir1/RCS/file1,v', 'subdir1/RCS/file2,v', 'subdir1/RCS/file3,v')],
"dir_list correct for recurse_first=>'1', include=>'qr/\,v\$/'");

is_deeply(
	[sort(dir_list($dirname, { exclude => qr/,v$/, recurse => 1 }))],
	[grep { $have_rcs ? 1 : !m{RCS} } sort(qw(file1 file2 file3 RCS/ subdir1/ subdir1/file1
			subdir1/file2 subdir1/file3 subdir1/RCS/)
	)],
"dir_list correct for recurse=>'1', exclude=>'qr/\,v\$/'");

is_deeply(
	[grep { $have_rcs ? 1 : !m{RCS} } sort(dir_list($dirname, { include => qr/,v$/, exclude => qr/RCS/, recurse_first => 1 }))],
	[grep { $have_rcs ? 1 : !m{RCS} } sort('RCS/file1,v', 'RCS/file2,v', 'RCS/file3,v',
		  'subdir1/RCS/file1,v', 'subdir1/RCS/file2,v', 'subdir1/RCS/file3,v')],
"dir_list correct for recurse_first=>'1',include=>'qr/\,v\$/',exclude=>'qr/RCS/'");

is_deeply(
	[sort(dir_list($dirname, { include => qr/,v$/, exclude => qr/RCS/, recurse => 1, filter_order => 'exclude,include' }))],
	[],
"dir_list correct for recurse=>'1',include=>'qr/\,v\$/',exclude=>'qr/RCS/',filter_order=>'exclude,include'");

my @path_and_file;
my @file;
my @path;

TODO: {

    local $TODO = "Re-implement without using RCS directories - or create RCS directories manually";
    
	(@path_and_file, @file, @path) = ();

	sub filter {
		push @path_and_file, $_[0];
		push @path, $_[1];
		push @file, $_[2];
	}

	dir_list("$dirname/RCS/", { include => \&filter }) if $have_rcs;

	is_deeply(
		[sort(@path_and_file, @file, @path)],
		[sort(
				("$dirname/RCS/file1,v"),
				("$dirname/RCS/file2,v"),
				("$dirname/RCS/file3,v"),
	
				("file1,v"),
				("file2,v"),
				("file3,v"),
	
				("$dirname/RCS/"),
				("$dirname/RCS/"),
				("$dirname/RCS/"),
			)],
			"dir_list calls include filter 'sub' with correct args");

	(@path_and_file, @file, @path) = ();

	dir_list("$dirname/RCS/", { exclude => \&filter }) if $have_rcs;
	is_deeply(
		[sort(@path_and_file, @file, @path)],
		[sort(
			("$dirname/RCS/file1,v"),
			("$dirname/RCS/file2,v"),
			("$dirname/RCS/file3,v"),

			("file1,v"),
			("file2,v"),
			("file3,v"),

			("$dirname/RCS/"),
			("$dirname/RCS/"),
			("$dirname/RCS/"),
		)],
		"dir_list calls exclude filter 'sub' with correct args");
}
