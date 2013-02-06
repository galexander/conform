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

extends 'Log::Any';

use Log::Any::Adapter;

sub set {
    shift if $_[0] eq __PACKAGE__;
    Log::Any::Adapter->set(@_);
}

sub note;
sub debug;
sub lines_prefix;

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
