package Conform::Site;
use Test::More qw(no_plan);
use strict;
use FindBin;

BEGIN {
    use lib "$FindBin::Bin/../lib";
    use_ok 'Conform::Site';
}

can_ok 'Conform::Site', 'version';
can_ok 'Conform::Site', 'uri';
can_ok 'Conform::Site', 'root';

# vi: set ts=4 sw=4:
# vi: set expandtab:
