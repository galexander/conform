package Conform::Test::Logger;
use strict;
use Test::More tests => 17;
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

my @logger_methods    = @log_any_methods, qw(note);

use_ok 'Conform::Logger', qw($log), @logger_methods;
is $Conform::Logger::VERSION, $Conform::VERSION, "version is OK";

can_ok 'Conform::Logger', 'set';
can_ok __PACKAGE__, @log_any_methods;
can_ok __PACKAGE__, @logger_methods;

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
    for (@log_any_methods) {
        no strict 'refs';
        &$_($_);
    }
};

is $trap->stderr, (join "\n", @log_any_methods) . "\n", "stderr logging OK";

Conform::Logger->set('Stdout');
trap { 
    for (@logger_methods) {
        $log->$_($_);
    }
};

is $trap->stdout, (join "\n", @logger_methods) . "\n", "stdout logging OK";

my ($fh, $filename) = tempfile(UNLINK => 1);

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

$log->info("info message");

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
Conform::Logger->set('Log4perl');
$log->info("test log message");

my ($logfh, $logfile) = tempfile(UNLINK => 1);

my $log_conf = <<EOCONF;
       log4perl.rootLogger=DEBUG
       log4perl.category.Conform.Test.Logger          = DEBUG, Logfile, Screen

       log4perl.appender.Logfile          = Log::Log4perl::Appender::File
       log4perl.appender.Logfile.filename = $logfile
       log4perl.appender.Logfile.layout   = Log::Log4perl::Layout::PatternLayout
       log4perl.appender.Logfile.layout.ConversionPattern = %p - %m%n

       log4perl.appender.Screen         = Log::Log4perl::Appender::Screen
       log4perl.appender.Screen.stderr  = 1
       log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout
     );
EOCONF

Log::Log4perl::init(\$log_conf);

use Conform::Logger qw(fatal);

trap {
    $log->debug("debug");
    errorf("foo");
    fatal "fatal";
};

is($trap->stderr, "DEBUG - debug\nERROR - foo\nFATAL - fatal\n", "log4perl screen appender OK");
# [3] lib/Test.pm 11 info message
file_ok($logfile, "DEBUG - debug\nERROR - foo\nFATAL - fatal\n", "log4perl file appender OK");

}


# vi: set ts=4 sw=4:
# vi: set expandtab:
