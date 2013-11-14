package Conform::Task;
use Moose;
use Data::Dump qw(dump);
use Conform::Logger qw($log trace debug notice warn fatal);
use Scalar::Util qw(blessed);

extends 'Conform::Work';

=head1  NAME

Conform::Task

=head1  SYNSOPSIS

use Conform::Task;

=head1 ABSTRACT

Conform::Task - descrete unit of work to be run by a conform agent.

=head1  DESCRIPTION

=cut

sub BUILD {
    my $self = shift;
    my $constraints = $self->constraints;
    $constraints->{unique} = 'name';
    $self;
}

=head1  METHODS

=over

=item B<run>

    $task->run();

=cut

sub run { trace;
    my $self     = shift;

    debug "Executing Task (id=%s,name=%s)",
          $self->id,
          $self->name;

    my $function = $self->impl;

    my @result   = $function->($self, @_);

    debug "Task (id=%s,name=%s,args=%s) returned %s",
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

