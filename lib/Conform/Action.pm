package Conform::Action;
use strict;
use Mouse;

=head1  NAME

Conform::Action

=head1  SYNSOPSIS

use Conform::Action;

=head1  DESCRIPTION


=cut

=head1   METHODS


=item    id

=cut

has 'id',      ( is => 'rw' );

=item    name

=cut

has 'name',    ( is => 'rw', isa => 'Str', required => 1,  );

=item    desc

=cut

has 'desc',    ( is => 'rw' );

=item    code

=cut

has 'code',    ( is => 'rw', isa => 'CodeRef' );


sub execute {
    my $self = shift;

    my $code = $self->code;

    $code ||= sub { print STDERR "@{[ $self->name ]} is not implemented" };

    $code->($self, @_)
}


=head1  SEE ALSO

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

1;

# vi: set ts=4 sw=4:
# vi: set expandtab:
