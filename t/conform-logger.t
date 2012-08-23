#!/usr/bin/perl -w
use Test::More qw(no_plan);
use strict;
use FindBin;

# TODO: expand on these

use Test::Trap;

BEGIN {
    use lib "$FindBin::Bin/../lib";
    use_ok 'Conform::Logger';
}


is $Conform::Logger::VERSION, $Conform::VERSION, "version is OK";

our $log;
my @log_methods = qw(trace
                     debug
                     info inform
                     notice
                     warning warn 
                     error err 
                     critical crit fatal 
                     alert
                     emergency);


use Conform::Logger qw($log);

ok $log, 'Log is defined';
can_ok $log, @log_methods;

trap { 
    for (@log_methods) {
        $log->$_($_);
    }
};

is $trap->stderr, (join "\n", @log_methods) . "\n", "logging OK";

# vi: set ts=4 sw=4:
# vi: set expandtab:
