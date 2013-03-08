package Conform::Test::Core::SafeMode;
use strict;

use Test::More tests => 9;
use Test::Trap;
use FindBin;
use lib "$FindBin::Bin/../lib";

BEGIN {
use_ok('Conform::Core', qw( action safe ))
    or die "# Conform::Core not available\n";
}

use Conform::Logger;
Conform::Logger->set('Stderr');

my $action = sub { warn "foo"; shift };

my $result;

############################################################################

{
	local $Conform::Core::safe_mode = 1;
	$result = trap { action 'message' => $action, 42 };

	is($result, 1, 'safe mode: action returns 1');
	is($trap->stderr, <<EOF, '  log is correct');
SKIPPING: message
EOF
}

$result = trap { action 'message' => $action, 42 };
is($result, 42, 'action is executed');
is($trap->stderr, <<EOF, '  log is correct');
message
foo
EOF

############################################################################

{
	local $Conform::Core::safe_mode = 1;
	$result = trap { safe $action, 42 };
	is($result, 1, 'safe mode: safe returns 1');
	is($trap->stderr, <<EOF, '  log is correct');
EOF
}

$result = trap { safe $action, 42 };
is($result, 42, 'safe action is executed');
is($trap->stderr, <<EOF, '  log is correct');
foo
EOF
