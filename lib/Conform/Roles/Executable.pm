package Conform::Executable;
use strict;
use Mouse;
use Conform::Logger qw($log);

=head1  NAME

Conform::Executable

=head1  SYNSOPSIS

use Conform::Executable;

=head1  DESCRIPTION


=cut


=head1   METHODS


=head2   name

=cut

has 'name',    ( is => 'rw' );

=head2   impl

=cut

has 'impl',    ( is => 'rw', isa => 'CodeRef' );

=head2  execute

=cut

sub execute {
    my $self = shift;
    $log->debugf("%s->execute(%s)", ref $self, $self->name);
    $self->impl->(@_);
}


=head1  SEE ALSO



=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

1;

# vi: set ts=4 sw=4:
# vi: set expandtab:
