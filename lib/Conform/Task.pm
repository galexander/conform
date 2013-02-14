package Conform::Task;
use Mouse;
use Data::Dump qw(dump);
use Conform::Logger qw($log);
use Conform::Debug qw(Trace Debug);

with 'Conform::Work';

=head1  NAME

Conform::Work

=head1  SYNSOPSIS

use Conform::Work;

=head1 ABSTRACT

Conform::Work - descrete unit of work to be run
by a conform agent.

=head1  DESCRIPTION

=cut

=head1  METHODS

=over

=item B<dependencies>

    $dependencies = $action->dependencies;
    $action->dependencies(\@dependencies);

=cut

has 'dependencies' => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { [] },
);

=item B<satisfies>

    $action->satisfies($dependency);

=cut

=item B<run>

    $task->run();

=cut

sub run { Trace;
    my $self     = shift;

    Debug "Executing Task (id=%s,name=%s)",
          $self->id,
          $self->name;

    my $function = $self->impl;
    my @result   = $function->($self, @_);

    Debug "Task (id=%s,name=%s,args=%s) returned %s",
          $self->id,
          $self->name,
          dump(\@result);

    return wantarray
            ? @result
            :\@result;
}



=back


=head1  SEE ALSO

L<conform> L<Conform::Task::Plugin>

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=head1  COPYRIGHT

Copyright 2012 (Gavin Alexander)

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module

=cut

1;

# vi: set ts=4 sw=4:
# vi: set expandtab:
