package Conform::Util::File;
use strict;
use base 'Exporter';
use File::Basename qw(dirname);
use File::Path qw(mkpath);
use Conform::Util::File::DirCompare;
use OIE::Utils qw(command);

our @EXPORT_OK = qw(dir_compare file_copy find_bin);

sub dir_compare {
    return Conform::FileUtil::DirCompare::compare(@_);
}

sub file_copy {
    my ($src, $dst) = @_;
    my $dir = dirname $dst;
    mkpath $dir
        or die "mkpath $dir";
    command "cp -f -a $src $dst";
}

sub find_bin {
    my $bin = shift;
    my @search = split ":", $ENV{PATH}||"/usr/bin:/bin/sbin/usr/local";
    for (@search) {
        return "${_}/${bin}"
            if -x "${_}/${bin}";
    }
    return undef;
}

1;
