package Conform::Task;
use strict;
use Mouse;

extends 'Conform::Action';

=head1  NAME

Conform::Task

=head1  SYNSOPSIS

use Conform::Task;

=head1  DESCRIPTION


=cut



=head1   METHODS


=head2   name

=cut

has 'name',    ( is => 'rw' );

=head2   desc

=cut

has 'desc',    ( is => 'rw' );

=head2   impl

=cut

has 'impl',    ( is => 'rw' );

=head2   requires

=cut

has 'requires', ( is => 'rw' );

=head2   provides

=cut

has 'provides', ( is => 'rw' );

=head2   actions

=cut

has 'actions', ( is => 'rw' );

=head2   configure

=cut

has 'configure', ( is => 'rw' );

=head2   begin

=cut

has 'begin',   ( is => 'rw' );

=head2   end

=cut

has 'end',     ( is => 'rw' );


=head1  SEE ALSO



=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

1;

# vi: set ts=4 sw=4:
# vi: set expandtab:
