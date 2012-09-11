package Conform::SiteLoader;
use Test::More qw(no_plan);
use Test::Trap;
use strict;
use FindBin;

BEGIN {
    use lib "$FindBin::Bin/../lib";
    use_ok 'Conform::SiteLoader';
}

can_ok 'Conform::SiteLoader', 'load';


# vi: set ts=4 sw=4:
# vi: set expandtab:
