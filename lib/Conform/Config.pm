package Conform::Config;
use Mouse;

=head1  NAME

Conform::Config

=head1  SYNSOPSIS

use Conform::Config;

=head1  DESCRIPTION

=cut

extends 'Config::Any';

my $root = undef;

sub set {
    my $self = shift;
    $root = shift;
}

=head1  SEE ALSO

L<Config::Any>

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

1;

# vi: set ts=4 sw=4:
# vi: set expandtab:
