package Conform::Logger;
use Moose;

our $VERSION = $Conform::VERSION;
use Carp qw(croak);
use Conform::Logger::Stderr;
use Data::Dumper;
use Carp qw(confess);

=head1  NAME

Conform::Logger

=head1  SYNSOPSIS

    use Conform::Logger qw($log
                       trace tracef is_trace
                       debug debugf is_debug
                       notice noticef info infof is_info
                       warning warningf warn warnf is_warn
                       error errorf is_error
                       fatal fatalf is_fatal);

    # configuration
    Conform::Logger->set('Stderr');
    Conform::Logger->set('Stdout');

    # Logging

    trace  "message";
    tracef "%s", "message";
    $log->trace("message");
    $log->tracef("%s", "message");

    debug  "message";
    debugf "%s", "message";
    $log->debug("message");
    $log->debugf("%s", "message");

    notice  "message";
    noticef "%s", "message";
    $log->notice("message");
    $log->noticef("%s", "message");

    note  "message";
    notef "%s", "message";
    $log->note("message");
    $log->notef("%s", "message");

    info  "message";
    infof "%s", "message";
    $log->info("message");
    $log->infof("%s", "message");

    warn  "message";
    warnf "%s", "message";
    $log->warn("message");
    $log->warnf("%s", "message");

    warning  "message";
    warningf "%s", "message";
    $log->warning("message");
    $log->warningf("%s", "message");

    error  "message";
    errorf "%s", "message";
    $log->error("message");
    $log->errorf("%s", "message");

    fatal  "message";
    fatalf "%s", "message";
    $log->fatal("message");
    $log->fatalf("%s", "message");


    # Checking Log Levels

    is_trace();
    $log->is_trace();    # True if trace messages would go through
    
    is_debug();
    $log->is_debug();    # True if debug messages would go through

    is_info();
    $log->is_info();     # True if info messages would go through

    is_warn();
    $log->is_warn();     # True if warn messages would go through

    is_error();
    $log->is_error();    # True if error messages would go through

    is_fatal();
    $log->is_fatal()    # True if fatal messages would go through


=head1  DESCRIPTION

Conform::Logger is the logging framework for conform.

=cut

use Conform::Logger::Log;

use constant LOG_LEVEL_TRACE    => 0;
use constant LOG_LEVEL_DEBUG    => 1;
use constant LOG_LEVEL_INFO     => 2;
use constant LOG_LEVEL_NOTICE   => 3;
use constant LOG_LEVEL_WARNING  => 4;
use constant LOG_LEVEL_ERROR    => 5;
use constant LOG_LEVEL_FATAL    => 6;
use constant LOG_LEVEL_CRITICAL => 7;

sub LOG_LEVEL {
    return $_[0]              if $_[0] =~ m{[0-7]};
    return LOG_LEVEL_TRACE    if $_[0] eq 'ALL';
    return LOG_LEVEL_TRACE    if $_[0] eq 'TRACE';
    return LOG_LEVEL_DEBUG    if $_[0] eq 'DEBUG';
    return LOG_LEVEL_INFO     if $_[0] eq 'INFO';
    return LOG_LEVEL_NOTICE   if $_[0] eq 'NOTICE';
    return LOG_LEVEL_NOTICE   if $_[0] eq 'NOTE';
    return LOG_LEVEL_WARNING  if $_[0] eq 'WARN';
    return LOG_LEVEL_WARNING  if $_[0] eq 'WARNING';
    return LOG_LEVEL_ERROR    if $_[0] eq 'ERROR';
    return LOG_LEVEL_FATAL    if $_[0] eq 'FATAL';
    return LOG_LEVEL_CRITICAL if $_[0] eq 'CRITICAL';
    croak "invalid LOG_LEVEL $_[0]";
}

our @LOG_FUNCTIONS = qw(
    trace
    debug
    info
    note
    notice
    warning
    warn
    error
    fatal
    critical
);

our @LOG_EXPORT_OK = (
    '$log',
    map { ("$_", "${_}f", "is_${_}") } @LOG_FUNCTIONS
);

our %loggers = ();
our $root_logger 
    = $loggers{'root'} 
    = Conform::Logger->new(category => 'root', 
                           level => LOG_LEVEL('INFO'),
                           appender => Conform::Logger::Stderr->new());

our $root_level = LOG_LEVEL('INFO');
our $root_appender = Conform::Logger::Stderr->new();

our %LOG_FORMAT = (
    'TRACE' => '[%T] %L %P %s %m',
    'DEBUG' => '[%T] %L %P %s %m',
    'default' => '[%T] %L %m',
);

sub _msg {
    my $caller  = shift;
    my $level   = shift;
    my $content = shift ||'';
    my %msg = (
        'package'    => $caller->[0],
        'filename'   => $caller->[1],
        'line'       => $caller->[2],
        'subroutine' => $caller->[3],
        'hasargs'    => $caller->[4],
        'wantarray'  => $caller->[5],
        'evaltext'   => $caller->[6],
        'is_require' => $caller->[7],
        'hints'      => $caller->[8],
        'bitmask'    => $caller->[9],
        'hinthash'   => $caller->[10],
        'content'    => $content,
        'level'      => $level,
        'time'       => time,
    );
    my $package   = $msg{package} ||'';
    my $localtime = scalar localtime $msg{time};
    (my $content_wrapped = $content) =~ s/[\r\n]//g;
    my $subroutine = $msg{subroutine} || 'ANON';

    $subroutine =~ s/^$package\:://;

    if ($package =~ /^Conform/) {
       1 while $package =~ s/(\w)(\S+?)(?:\::)/${1}::/g;
    }

    $msg{package} = $package;
    $msg{localtime} = $localtime;
    $msg{content_wrapped} = $content_wrapped;
    $msg{subroutine} = "${subroutine}()";

    return \%msg;
}


for my $method (@LOG_FUNCTIONS) {
    my $printf = sprintf "%sf",   $method;
    my $print  = sprintf "%s",    $method;
    my $check  = sprintf "is_%s", $method;

    no strict 'refs';
    *$print = sub {
        my $self    = shift;
        my @caller  = caller(1);
        my $logger  = $self->get_logger(category => $caller[0]);
        if ($logger->$check()) {
            my $fmt;
            if (scalar @_ > 1) {
                $fmt = shift;
            } else {
                $fmt = "%s";
            }
            $logger->log(_msg \@caller, uc "$method", sprintf $fmt, @_);
        }
    };
    
    *$printf = sub {
        my $self   = shift;
        my @caller = caller(1);
        my $logger = $self->get_logger(category => $caller[0]);
        if ($logger->$check()) {
            my $fmt = shift;
            $logger->log(_msg \@caller, uc "$method", sprintf $fmt, @_ );
        }
    };

    my $log_level = LOG_LEVEL(uc $method);

    *$check = sub {
        my $self = shift;
        return $self->level <= $log_level;
    };
}

sub get_root_logger {
    my $package = shift;
    return exists $loggers{'root'}
        ? $loggers{'root'}
        : $root_logger
            = $loggers{'root'}
            = Conform::Logger->new(category => 'root', level => $root_level,  appender => $root_appender);
}

sub get_logger {
    my $package = shift;
    my %args = @_;
    my $category = $args{category} || caller;
    if (my $logger = $loggers{$category}) {
        return $logger;
    }
    return $package->get_root_logger();
}

sub _fmt {
    my ($fmt, $msg) = @_;
    my %map = (
        't' => $msg->{time},
        'T' => $msg->{localtime},
        'm' => $msg->{content},
        'z' => $msg->{content_wrapped},
        'P' => $msg->{package}||'',
        's' => $msg->{subroutine},
        'f' => $msg->{filename}||'',
        'l' => $msg->{line}||'',
        'L' => $msg->{level},
    );
    1 while $fmt =~ s|%(\w)|exists $map{$1} ? $map{$1} : ''|ge;
    return $fmt;
}

sub log {
    my $self = shift;
    my $msg  = shift;
    my $appender = $self->appender;
    
    my $fmt = $LOG_FORMAT{$msg->{level}};
    $fmt  ||= $LOG_FORMAT{'default'};

    $msg->{content} = _fmt $fmt, $msg;

    $appender->log($msg);
}

sub _chomp {
    my @lines = @_;
    chomp $lines[$#lines];
    @lines;
}

$SIG{__WARN__} = sub {
    $root_logger->warn(_chomp(@_));
};

$SIG{__DIE__} = sub {
    die @_ if $^S;
    my $state = $^S;
    $root_logger->fatal(_chomp(@_)) if defined $^S;
    die @_;
};


sub import {
    my $package  = shift;
    my @import_caller   = caller;
    my $import_caller   = $import_caller[0];

    my $log      = grep /^\$/,  @_;
    my @methods  = grep !/^\$/, @_;

    LOG_METHOD:
    for my $method (grep !/^is_/, @methods) {

        next LOG_METHOD unless grep /^\Q$method\E$/, @LOG_EXPORT_OK;

        no strict 'refs';
        unless (defined &{"${import_caller}\::${method}"}) {
            *{"${import_caller}\::${method}"} = sub {
                my @caller = caller(1);
                
                my $logger = __PACKAGE__->get_logger(category => $caller[0]);
                (my $check = $method) =~ s!^(\S+)f?!is_${1}!;
                if ($logger->$check()) {
                    my $fmt = shift;
                    if (scalar @_) {
                        $logger->log(_msg \@caller, uc "$method", sprintf $fmt, @_);
                    } else {
                        $logger->log(_msg \@caller, uc "$method", $fmt);
                    }
                }
            };
        }
    }

    CHECK_METHOD:
    for my $method (grep /^is_/, @methods) {

        next CHECK_METHOD unless grep /^\Q$method\E$/, @LOG_EXPORT_OK;

        no strict 'refs';
        unless (defined &{"${import_caller}\::${method}"}) {
            *{"${import_caller}\::${method}"} = sub {
                my $logger = __PACKAGE__->get_logger(category => (caller)[0]);
                return $logger->$method();
            };
        }
    }


    if ($log) {
        my $log = $package->get_logger(category => $import_caller[0]);
        no strict 'refs';
        my $varname = "$import_caller\::log";
        *$varname = \$log;
    }
}

=head1  CLASS METHODS

=head2 set
    
    Conform::Logger->set($appender)

I<Parameters>

=over 4

=item * 

$appender

=back

=cut

=head2 get_logger

    Conform::Logger->get_logger(%args)

I<Parameters>

=over 4

=item *

%args

=back

I<Returns>

=over 4

=item * 

$logger

=back

=cut

my $_log = Conform::Logger::Log->new();

sub BUILD { 
    my $self = shift;
}

sub get_log {
    return $_log;
}

has 'category' => (
    is => 'rw',
    isa => 'Str',
);

has 'appender' => (
    is => 'rw',
    isa => 'Conform::Logger::Appender',
    default => sub { Conform::Logger::Stderr->new() },
);

has 'level' => (
    is => 'rw',
    isa => 'Int',
    default => sub { $root_level },
);

sub get_appender {
    my $class = shift;
    my $appender_class = shift;
    if ($appender_class =~ m{^::}) {
        $appender_class = sprintf "%s%s", __PACKAGE__, $appender_class;
    }
    eval "require $appender_class;";
    print STDERR "$@";
    if (my $err = $@) {
        die "$appender_class not installed or contains an error $err $!";
    }
    $appender_class->new(@_);
}

sub set_appender {
    my $package = shift;
    my $caller  = caller;

    my $category;
    my $appender;
    my $level;

    if (@_ == 1) {
        $appender = shift
            or croak "appender is required";
        unless (ref $appender) {
            $appender = $package->get_appender($appender);
        }
    } else {
        my %args = @_;
        $appender = delete $args{appender}
            or croak "appender is required";
        unless (ref $appender) {
            $appender = $package->get_appender($appender, @_);
        }
        $category = $args{category};
        $level = $args{level};
    }

    $category = $caller unless defined $category;
    $level    = LOG_LEVEL(defined $level ? $level : 'INFO');

    if (exists $loggers{$category}) {
        $loggers{$category}->appender($appender);
        $loggers{$category}->level($level);
    } else {
        $loggers{$category} = Conform::Logger->new(category => $category,
                                                   appender => $appender,
                                                   level    => $level);

        if ($category eq 'root') {
            $root_logger   = $loggers{$category};
            $root_appender = $appender;
            $root_level    = $level;
        }
    }
}

sub set_level {
    my $package = shift;
    if (ref $package) {
        $package->level(@_);
    } else {
        $root_level = shift @_;
    }
}

sub set_default {
    my $package = shift;
    my %args = @_;
    my $category = $args{category} || 'root';
    my $level    = exists $args{level}
                        ? LOG_LEVEL($args{level})
                        : LOG_LEVEL('INFO');
    my $appender = $args{appender} || '::Stderr';
    $package->set_level($level);
    $package->set_appender(category => $category, appender => $appender, level => $level);
}


=head1  METHODS

=head2 trace, tracef

    trace  "message";
    tracef "%s", "message";
    $log->trace("message");
    $log->tracef("%s", "message");

=cut

=head2 debug, debugf

    debug  "message";
    debugf "%s", "message";
    $log->debug("message");
    $log->debugf("%s", "message");

=cut

=head2 notice, noticef

    notice  "message";
    noticef "%s", "message";
    $log->notice("message");
    $log->noticef("%s", "message");

=cut

=head2 note, notef (DEPRECATED)

    note  "message";
    notef "%s", "message";
    $log->note("message");
    $log->notef("%s", "message");

=cut

=head2 info, infof

    info  "message";
    infof "%s", "message";
    $log->info("message");
    $log->infof("%s", "message");

=cut

=head2 warn, warnf

    warn  "message";
    warnf "%s", "message";
    $log->warn("message");
    $log->warnf("%s", "message");

=head2 warning, warningf (DEPRECATED)

    warning  "message";
    warningf "%s", "message";
    $log->warning("message");
    $log->warningf("%s", "message");

=cut

=head2 error, errorf

    error  "message";
    errorf "%s", "message";
    $log->error("message");
    $log->errorf("%s", "message");

=cut

=head2 fatal, fatalf

    fatal  "message";
    fatalf "%s", "message";
    $log->fatal("message");
    $log->fatalf("%s", "message");

=cut

=head2 is_trace

    is_trace();
    $log->is_trace();

=cut

=head2 is_debug
    
    is_debug();
    $log->is_debug();

=cut

=head2 is_info

    is_info();
    $log->is_info();

=cut

=head2 is_warn

    is_warn();
    $log->is_warn();

=cut

=head2 is_error

    is_error();
    $log->is_error();

=cut

=head2 is_fatal

    is_fatal();
    $log->is_fatal();

=cut

=head1  SEE ALSO

=over

=item   L<Log::Any>

=item   L<Log::Any::Adapter>

=back

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

1;

# vi: set ts=4 sw=4:
# vi: set expandtab:

