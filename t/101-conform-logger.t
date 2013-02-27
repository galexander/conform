package Conform::Test::Logger;
use strict;
use Test::More tests => 15;
use Test::Trap;
use FindBin;
use File::Temp qw(tempfile);
use lib "$FindBin::Bin/../lib";
use Test::Files;


our $log;
my @log_any_methods = qw(trace tracef
                     debug debugf
                     info infof inform informf
                     notice noticef
                     warning warningf warn warnf
                     error errorf err errf
                     critical criticalf crit critf
                     fatal fatalf
                     alert alertf
                     emergency emergencyf);

my @logger_methods = @log_any_methods;
push @logger_methods,
        qw(note);

use_ok 'Conform::Logger', qw($log), @logger_methods;
is $Conform::Logger::VERSION, $Conform::VERSION, "version is OK";

can_ok 'Conform::Logger', 'set';
can_ok 'Conform::Logger', @log_any_methods;
can_ok 'Conform::Logger', @logger_methods;

ok $log, 'Log is defined';

can_ok $log, @log_any_methods;

Conform::Logger->set('Stderr');
trap { 
    for (@log_any_methods) {
        $log->$_($_);
    }
};

is $trap->stderr, (join "\n", @log_any_methods) . "\n", "stderr logging OK";

Conform::Logger->set('Stderr');
trap {
    for (@logger_methods) {
        no strict 'refs';
        &$_($_);
    }
};

is $trap->stderr, (join "\n", @logger_methods) . "\n", "stderr logging OK";

Conform::Logger->set('Stdout');
trap { 
    for (@log_any_methods) {
        $log->$_($_);
    }
};

is $trap->stdout, (join "\n", @log_any_methods) . "\n", "stdout logging OK";

my ($fh, $filename) = tempfile();

Conform::Logger->set('File', $filename);

for (@log_any_methods) {
    $log->$_($_);
}

sub strip_timestamp {
    $_[0] =~ s{^.+\] }{};
    $_[0];
}

file_filter_ok $filename, (join "\n", @log_any_methods) ."\n", \&strip_timestamp, "file logging OK";

eval "use Log::Log4perl; use Log::Any::Adapter::Log4perl;";
SKIP : {
skip "Log::Log4perl and Log::Any::Adapter::Log4perl not available" => 10 if $@;

Log::Log4perl->easy_init($Log::Log4perl::ERROR);

Conform::Logger->set('Log4perl');

trap { $log->debug("debug"); };
is($trap->stderr, "", "log level set OK - no debug");
trap { debug("debug2"); };
is($trap->stderr, "", "log level set OK - no debug");
trap { $log->error("error"); };
like ($trap->stderr, qr/error\n/, "log level set OK error level");
trap { error("error2"); };
like ($trap->stderr, qr/error2\n/, "log level set OK error level");

}


# vi: set ts=4 sw=4:
# vi: set expandtab:
