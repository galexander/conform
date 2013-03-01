package Conform::Logger;
use Mouse;

our $VERSION = $Conform::VERSION;

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
    Conform::Logger->set('File' => 'file');

    Conform::Logger->set('Log4perl');

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

use Log::Any::Adapter;

extends 'Log::Any';

# we use this flag to detect if we are using Log4perl
my $Log4perl = 0;

our @LOG_EXPORT_OK = (qw(
    $log
    trace tracef is_trace
    debug debugf is_debug
    info infof   is_info
    note notef
    notice noticef is_notice
    warning warningf
    warn warnf is_warn
    error errorf is_error
    fatal fatalf is_fatal
));

sub import {
    my $package  = shift;
    my $caller   = caller;

    my $log      = grep /^\$/,  @_;
    my @methods  = grep !/^\$/, @_;

    METHOD:
    for my $method (@methods) {

        next METHOD unless grep /^\Q$method\E$/, @LOG_EXPORT_OK;

        no strict 'refs';
        unless (defined &{"${caller}\::${method}"}) {
            *{"${caller}\::${method}"} = sub {
                if ($Log4perl) {

                    # If we use log4perl then the
                    # caller depth has to be incremented
                    # so that line numbers, caller, method
                    # etc are reported correctly

                    local $Log::Log4perl::caller_depth
                            = $Log::Log4perl::caller_depth + 1;

                    __PACKAGE__->get_logger(category => caller)
                               ->$method(@_); 

                } else {

                    __PACKAGE__->get_logger(category => caller)
                               ->$method(@_);

                }
            };
        }
    }

    if ($log) {
        my $log = $package->get_logger(category => $caller);
        no strict 'refs';
        my $varname = "$caller\::log";
        *$varname = \$log;
    }
}

=head1  CLASS METHODS

=head2 set
    
    Conform::Logger->set($adapter)

I<Parameters>

=over 4

=item * 

$adapter

=back

=cut

sub set {
    shift if $_[0] eq __PACKAGE__ || ref $_[0];
    my $adapter = shift;
    if ($adapter eq 'Log4perl') {
        require Log::Log4perl;
        $Log4perl++;
    }
    Log::Any::Adapter->set($adapter, @_);
}

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
