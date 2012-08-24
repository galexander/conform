package Conform::Agent;
use Test::More qw(no_plan);
use strict;
use FindBin;

BEGIN {
    use lib "$FindBin::Bin/../lib";
    use_ok 'Conform::Agent';
}

can_ok 'Conform::Agent', 'runtime';
can_ok 'Conform::Agent', 'site';

# vi: set ts=4 sw=4:
# vi: set expandtab:
