package Conform::Logger;
use Mouse;

our $VERSION = $Conform::VERSION;

=head1  NAME

Conform::Logger

=head1  SYNSOPSIS

use Conform::Logger qw($log);

$log->debug("msg");
$log->errorf("%s msg", $msg );

use Conform::Logger qw(debug);

debug "message";

=head1  DESCRIPTION

Conform::Logger 

=cut

use Log::Any::Adapter;

extends 'Log::Any';

my $Log4perl = 0;

our @LOG_METHODS = (qw(
    trace
    tracef
    debug
    debugf
    info
    infof
    inform
    informf
    note
    notef
    notice
    noticef
    warning
    warningf
    warn
    warnf
    error
    errorf
    err
    errf
    critical
    criticalf
    crit
    critf
    alert
    alertf
    fatal
    fatalf
    emergency
    emergencyf
));

sub import {
    my $package = shift;
    my $caller  = caller;
    my $log     = grep /^\$/,  @_;
    my @other   = grep !/^\$/, @_;

    no strict 'refs';
    for my $method (@other) {

        unless (defined &{"${caller}\::${method}"}) {
            *{"${caller}\::${method}"} = sub {
                if ($Log4perl) {
                    local $Log::Log4perl::caller_depth
                            = $Log::Log4perl::caller_depth + 1;
                    __PACKAGE__->get_logger( category => caller )->$method(@_);
                } else {
                    __PACKAGE__->get_logger( category => caller )->$method(@_);
                }
            };
        }
    }

    if ($log) {
        my $log = $package->SUPER::get_logger( category => $caller );
        no strict 'refs';
        my $varname = "$caller\::log";
        *$varname = \$log;
    }
}

sub set {
    shift if $_[0] eq __PACKAGE__ || ref $_[0];
    my $adapter = shift;
    if ($adapter eq 'Log4perl') {
        require Log::Log4perl;
        $Log4perl++;
    }
    Log::Any::Adapter->set($adapter, @_);
}

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
