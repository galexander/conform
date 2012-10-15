package Conform::Role::Action;
use Mouse::Role;

with 'Conform::Directive';

=head1  NAME

Conform::Action

=head1  SYNSOPSIS

use Conform::Role::Action;

=head1  DESCRIPTION

=cut

=head1   METHODS

=head2   name

L<Conform::Directive::name>

=cut

=head2   desc

L<Conform::Directive::desc>

=cut

requires 'execute';

=head1  SEE ALSO

L<Conform::Directive>

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

1;

# vi: set ts=4 sw=4:
# vi: set expandtab:
