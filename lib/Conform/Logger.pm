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
    Conform::Logger->configure('Stderr');
    Conform::Logger->configure('Stderr', 'INFO');
    Conform::Logger->configure('Stdout');
    Conform::Logger->configure('Stdout', 'ALL');
    Conform::Logger->configure('Stderr', { category => 'root', level => 'debug' });
    Conform::Logger->configure('Stderr', 'TRACE', { category => 'root', level => 'debug' });
    Conform::Logger->configure('Stdout' => { category => 'root', level => 'debug' });
    Conform::Logger->configure('Stdout' 'DEBUG', => { category => 'root', level => 'debug' });
    Conform::Logger->configure({ category => 'root', level => 'INFO', appenders => {
                                    'file' => {
                                        type => '::File',
                                        level => 'debug',
                                        formatter => {
                                            'TRACE' => '[%T] %L %P %s %m',
                                            'DEBUG' => '[%T] %L %P %s %m',
                                            'default' => '[%T] %L %m',
                                        },
                                    },
                               });

    
    

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
use constant LOG_LEVEL_MIN      => LOG_LEVEL_TRACE;
use constant LOG_LEVEL_MAX      => LOG_LEVEL_CRITICAL;

sub LOG_LEVEL {
    return $_[0]              if $_[0] =~ /^\d$/ && $_[0] >= LOG_LEVEL_MIN && $_[0] <= LOG_LEVEL_MAX;
    my $level = uc $_[0];
    return LOG_LEVEL_TRACE    if $level eq 'ALL';
    return LOG_LEVEL_TRACE    if $level eq 'TRACE';
    return LOG_LEVEL_DEBUG    if $level eq 'DEBUG';
    return LOG_LEVEL_INFO     if $level eq 'INFO';
    return LOG_LEVEL_NOTICE   if $level eq 'NOTICE';
    return LOG_LEVEL_NOTICE   if $level eq 'NOTE';
    return LOG_LEVEL_WARNING  if $level eq 'WARN';
    return LOG_LEVEL_WARNING  if $level eq 'WARNING';
    return LOG_LEVEL_ERROR    if $level eq 'ERROR';
    return LOG_LEVEL_FATAL    if $level eq 'FATAL';
    return LOG_LEVEL_CRITICAL if $level eq 'CRITICAL';
    croak "invalid LOG_LEVEL $level";
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

our %LOGGER = ();

sub _traverse_namespace;
sub _traverse_namespace {
    my $package = shift;
    my $sub = shift;
    my @parts = split '::', $package;
    while (@parts) {
        my $check = join '::', @parts;
        if ($sub->($check)) {
            return $check;
        }
        pop @parts;
    }
    return 0;
}

sub get_root_logger {
    if ($LOGGER{'root'}) {
        return $LOGGER{'root'};
    }
    return $LOGGER{'root'} = Conform::Logger->new( category => 'root',
                                                   level => LOG_LEVEL('INFO'),
                                                   formatter => {
                                                        'TRACE' => '[%T] %L %P %s %m',
                                                        'DEBUG' => '[%T] %L %P %s %m',
                                                        'default' => '[%T] %L %m',
                                                   },
                                                   appenders => {
                                                        'stderr' => Conform::Logger::Stderr->new(
                                                                                id => 'stderr',
                                                                                level    => LOG_LEVEL('INFO'),
                                                                                formatter => {
                                                                                    'TRACE' => '[%T] %L %P %s %m',
                                                                                    'DEBUG' => '[%T] %L %P %s %m',
                                                                                    'default' => '[%T] %L %m',
                                                                                }),
                                                    });
}

sub _get_logger {
    my $category = shift;
    return $LOGGER{root} unless exists $LOGGER{$category};
    return $LOGGER{$category};
}

sub find_logger {
    my $package = shift;
    my $category = shift;
    if ($category eq 'root') {
        return $package->get_root_logger();
    }
    my $logger;
    if ($logger = _traverse_namespace $category, sub { exists $LOGGER{$_[0]} }) {
        return $LOGGER{$logger};
    }
    return $package->get_root_logger();
}

sub _create_appender {
    my $package = shift;
    my %args = @_;
    my $type = $args{'type'};
    my $appender;
    $type = sprintf "::%s", ucfirst $type
                if $type =~ /^[a-z]/;
    $type = sprintf "Conform::Logger%s", $type
                if ($type =~ /^::/);

    eval "require $type;";
    die "$@"
        if $@;

    return $type->new(%args);
}

sub configure {
    my $package = shift;
    my $root    = $package->get_root_logger();
    my @conf = ();
    if (!ref $_[0]) {
        my $appender = shift @_;
        my $level = shift @_ unless ref $_[0];
        $level = $root->level
            unless defined $level;
        $level = LOG_LEVEL($level);
        push @conf, { level => $level, appenders => { $appender => { type => $appender,  ref $_[0] ? %{$_[0]} : () } } };
    } else {
        @conf = @_;
    }
    for my $conf (@conf) {

        my $category  = $conf->{'category'};
        my $level     = $conf->{'level'};
        my $appenders = $conf->{'appenders'};
        my $formatter = $conf->{'formatter'};

        $category   = 'root'            unless defined $category;

        my $logger = $package->_get_logger($category);
        unless (defined $logger) {
            $logger = $root->clone(category => $category);
        }
            
        $level      = $logger->level      unless defined $level;
        $appenders  = $logger->appenders  unless defined $appenders;
        $formatter  = $logger->formatter  unless defined $formatter;

        $level = LOG_LEVEL($level);

        my %args = ();
        my %appenders = ();

        for my $appender_id (keys %$appenders) {
            my $appender = $appenders->{$appender_id};
            if (ref $appender) {
                if (blessed $appender && $appender->isa('Conform::Logger::Appender')) {
                    my $impl = $appender->clone(id => $appender_id);
                    $appenders{$impl->id} = $impl;
                } else {
                    my $impl = $package->_create_appender(id => $appender_id, level => $level, %$appender);
                    $appenders{$impl->id} = $impl;
                }
            } else {
                my $impl = $package->_create_appender(id => $appender_id, type => $appender);
                $appenders{$impl->id} = $impl;
            }
        }
        $logger->level($level);
        $logger->appenders(\%appenders);
        $logger->formatter($formatter);

        $LOGGER{$logger->category} = $logger;
    }
}

sub clone {
    my $self = shift;
    my %args = @_;
    my $package = ref $self;
    $args{'id'} ||= $self->id;
    $args{'category'} ||= $self->category;
    $args{'level'} = $self->level unless exists $args{level};
    $args{'formatter'} ||= $self->formatter;
    $args{'appenders'} ||= $self->appenders;
    $package->new(%args);
}

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
        my $logger = $self;
        if ($logger->$check()) {
            my $fmt;
            if (scalar @_ > 1) {
                $fmt = shift;
            } else {
                $fmt = "%s";
            }
            $logger->_log(_msg \@caller, uc "$method", sprintf $fmt, @_);
        }
    };
    
    *$printf = sub {
        my $self   = shift;
        my @caller = caller(1);
        my $logger = $self;
        if ($logger->$check()) {
            my $fmt = shift;
            $logger->_log(_msg \@caller, uc "$method", sprintf $fmt, @_ );
        }
    };

    my $log_level = LOG_LEVEL(uc $method);

    *$check = sub {
        my $self = shift;
        return $self->level <= $log_level;
    };
}

sub get_logger {
    my $package = shift;
    my %args = @_;
    my $category = $args{category} || caller;
    return $package->find_logger($category);
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

sub _log {
    my $self = shift;
    my $msg  = shift;
    for my $appender (values %{$self->appenders}) {
        my $fmt = $appender->get_formatter($msg->{level});
        $fmt ||= $appender->get_formatter('default');
        $msg->{content} = _fmt $fmt, $msg;
        $appender->log($msg);
    }
}

sub _chomp {
    my @lines = @_;
    chomp $lines[$#lines];
    @lines;
}

$SIG{__WARN__} = sub {
    __PACKAGE__->get_logger(category => 'root')->warn(_chomp(@_));
};

$SIG{__DIE__} = sub {
    die @_ if $^S;
    my $state = $^S;
    __PACKAGE__->get_logger(category => 'root')->fatal(_chomp(@_)) if defined $^S;
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
                (my $check = $method) =~ s!^(\S+)!is_$1!;
                $check =~ s{f$}{};
                if ($logger->$check()) {
                    my $fmt = shift;
                    if (scalar @_) {
                        $logger->_log(_msg \@caller, uc "$method", sprintf $fmt, @_);
                    } else {
                        $logger->_log(_msg \@caller, uc "$method", $fmt);
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
    
    Conform::Logger->configure($appender)

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

has 'id' => (
    is => 'rw',
);

has 'appenders' => (
    is => 'rw',
    isa => 'HashRef',
);

has 'formatter' => (
    is => 'rw',
    isa => 'HashRef',
);

has 'category' => (
    is => 'rw',
    isa => 'Str',
);

has 'level' => (
    is => 'rw',
    isa => 'Int',
    default => sub { LOG_LEVEL('info') },
);

sub get_formatter {
    my $self = shift;
    my $level = shift;
    my $formatters = $self->formatter;
    return $formatters->{$level};
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

