use strict;
use Test::More tests => 13;
use Test::Trap;
use FindBin;
use File::Temp qw(tempfile);
use lib "$FindBin::Bin/../lib";
use Test::Files;

our $log;

my @log_any_methods = (qw(
    trace tracef 
    debug debugf 
    info infof
    notice noticef
    warning warningf
    warn warnf
    error errorf 
    fatal fatalf
));

my @logger_methods  = @log_any_methods, qw(note);

my @check_log_methods = (qw(
    is_trace
    is_debug
    is_info
    is_warn
    is_error
    is_fatal));
    
use_ok 'Conform::Logger', qw($log),
                          @logger_methods,
                          @check_log_methods;

is $Conform::Logger::VERSION, $Conform::VERSION, "version is OK";

can_ok 'Conform::Logger', 'get_logger';
can_ok __PACKAGE__, @log_any_methods;
can_ok __PACKAGE__, @logger_methods;
can_ok __PACKAGE__, @check_log_methods;

ok $log, 'Log is defined';

can_ok $log, @log_any_methods;

Conform::Logger->configure('::Stderr', ALL => { 
        formatter => {
            'default' => '%m'
        }
});

trap { 
    for (@log_any_methods) {
        $log->$_($_);
    }
};

is $trap->stderr, (join "\n", @log_any_methods) . "\n", "stderr logging OK";

trap {
    for (@log_any_methods) {
        no strict 'refs';
        &$_($_);
    }
};

is $trap->stderr, (join "\n", @log_any_methods) . "\n", "stderr logging OK";

Conform::Logger->configure('stdout', ALL => {
                formatter => {
                    'default' => '%m',
                }
});

trap { 
    for (@logger_methods) {
        $log->$_($_);
    }
};

is $trap->stdout, (join "\n", @logger_methods) . "\n", "stdout logging OK";

Conform::Logger->configure('stdout', 'INFO' => {
        formatter => {
            'ERROR' => '%L %m',
        },
});

trap {
    $log->debug("some debug");
    $log->info("foo");
    debug("bar");
    info("baz");
};

is $trap->stdout, "foo\nbaz\n", 'log level OK';

trap {
    $log->error("some text");
    error("some more error text");
};

is $trap->stdout, "ERROR some text\nERROR some more error text\n", "formatted message OK";

# vi: set ts=4 sw=4:
# vi: set expandtab:
