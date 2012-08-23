package Conform::Role::Action;

use Mouse::Role;

use Conform::Dispatcher 'register';

=head1  NAME

Conform::Role::Action

=head1  SYNSOPSIS

 use Mouse;
 with qw/ Conform::Role::Action /;

 sub foo {}

 __PACKAGE__->register();

=head1  DESCRIPTION


=cut

=head1   METHODS


=item    name

=cut

has 'name',    ( is => 'rw', isa => 'Str', required => 1,  );

=item    desc

=cut

has 'desc',    ( is => 'rw' );

=item    registration

FIXME: maybe a better name for this?

=cut

with 'registration';

=head1  SEE ALSO

 L<Conform>

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

1;

# vi: set ts=4 sw=4:
# vi: set expandtab:
