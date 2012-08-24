package Conform::Site::Local;
use Test::More qw(no_plan);
use strict;
use FindBin;

BEGIN {
    use lib "$FindBin::Bin/../lib";
    use_ok 'Conform::Site::Local';
}

Conform::Logger->set('Stderr');



my $uri = "$FindBin::Bin/data/site";

my $site = Conform::Site::Local->new(uri => $uri);


# vi: set ts=4 sw=4:
# vi: set expandtab:
