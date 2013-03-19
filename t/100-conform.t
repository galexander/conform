use strict;

use Test::More tests => 2;
use FindBin;

use lib "$FindBin::Bin/../lib";
use_ok(qw(Conform));

is $Conform::VERSION, qw(0.01), 'version OK'

# vi: set ts=4 sw=4:
# vi: set expandtab:
