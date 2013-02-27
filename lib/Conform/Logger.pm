package Conform::Logger;
use Mouse;

our $VERSION = $Conform::VERSION;

=head1  NAME

Conform::Logger

=head1  SYNSOPSIS

use Conform::Logger qw($log);

$log->debug("msg");
$log->errorf("%s msg", $msg );

=head1  DESCRIPTION

Conform::Logger 

=cut

use Log::Any::Adapter;

use base 'Log::Any';
use Exporter qw(import);

use Log::Any qw($log);

our @EXPORT_OK = (qw(
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
    $log
));

sub set {
    shift if $_[0] eq __PACKAGE__;
    Log::Any::Adapter->set(@_);
}

sub _get_logger {
    my $caller = (caller(2))[0];
    return Log::Any->get_logger(category => $caller);
}

sub trace       { _get_logger->trace(@_); }
sub tracef      { _get_logger->tracef(@_); }

sub debug       { _get_logger->debug(@_); }
sub debugf      { _get_logger->debugf(@_); }

sub info        { _get_logger->info(@_); }
sub infof       { _get_logger->infof(@_); }

sub inform      { _get_logger->inform(@_); }
sub informf     { _get_logger->informf(@_); }

sub note        { _get_logger->notice(@_); }
sub notef       { _get_logger->noticef(@_); }

sub notice      { _get_logger->notice(@_); }
sub noticef     { _get_logger->noticef(@_); }

sub warning     { _get_logger->warning(@_); }
sub warningf    { _get_logger->warningf(@_); }

sub warn        { _get_logger->warn(@_); }
sub warnf       { _get_logger->warnf(@_); }

sub error       { _get_logger->error(@_); }
sub errorf      { _get_logger->errorf(@_); }

sub err         { _get_logger->err(@_); }
sub errf        { _get_logger->errf(@_); }

sub critical    { _get_logger->critical(@_); }
sub criticalf   { _get_logger->criticalf(@_); }

sub crit        { _get_logger->crit(@_); }
sub critf       { _get_logger->critf(@_); }

sub alert       { _get_logger->alert(@_); }
sub alertf      { _get_logger->alertf(@_); }

sub fatal       { _get_logger->fatal(@_); }
sub fatalf      { _get_logger->fatalf(@_); }

sub emergency   { _get_logger->emergency(@_); }
sub emergencyf  { _get_logger->emergencyf(@_); }

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
