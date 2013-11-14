package Conform::Runtime::Server::Linux;
use strict;
use Moose;
use Conform::Logger qw($log);

use Conform::Task::Plugin;

=head1  NAME

Conform::Runtime::Server::Linux

=head1  SYNSOPSIS

use Conform::Runtime::Server::Linux;

=head1  DESCRIPTION

=cut

extends 'Conform::Runtime::Server::Posix';

=head1  METHODS

=cut

=head1  ACTIONS

=cut

=head1 TASKS

=cut

=head2 Hostname

=cut

sub Hostname
     :Task {
}

=head1  SEE ALSO

L<Conform::Runtime::Server>

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

1;

# vi: set ts=4 sw=4:
# vi: set expandtab:
