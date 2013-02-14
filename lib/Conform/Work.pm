package Conform::Work;
use Mouse::Role;
use Data::Dump qw(dump);
use Conform::Logger qw($log);
use Conform::Debug qw(Trace Debug);

=head1  NAME

Conform::Work

=head1  SYNSOPSIS

use Conform::Action;

with 'Conform::Work';

=head1 ABSTRACT

Conform::Work - descrete unit of work to be run
by a conform agent.

=head1  DESCRIPTION

=cut

=head1  METHODS

=over

=item B<exec>

=cut

requires 'run';

=item B<id>

    $id = $work->id;
    $work->id($id);

=cut

has 'id' => (
    is => 'rw',
);

=item B<name>

    $name = $work->name;
    $work->name($name);

=cut

has 'name' => (
    is => 'rw',
);


=item B<prio>

    $work->prio;

=cut

has 'prio' => (
    is => 'rw',
    isa => 'Int',
    default => '50',
);

=item B<complete>

    $complete = $work->complete;

=cut
    
has 'complete' => (
    is => 'rw',
    isa => 'Bool',
);

1;

=item B<result>
    
    $result = $work->result;

=cut

has 'result' => (
    'is' => 'rw',
);

=item B<impl>
    
    $work->impl->();

=cut

has 'impl' => (
    is  => 'rw',
    isa => 'CodeRef',
    required => 1,
);

=item B<execute>

    $work->execute();

=cut

sub execute { Trace;
    my $self     = shift;

    Debug "Executing Work (id=%s,name=%s)",
          $self->id,
          $self->name;


    my @result   = $self->run(@_);

    Debug "Action (id=%s,name=%s) returned %s",
          $self->id,
          $self->name,
          dump(\@result);

    $self->result(\@result);

    $self->complete(1);

    return wantarray
            ? @result
            :\@result;
}

1;

=back

=head1  SEE ALSO

L<conform> L<Conform::Action> L<Conform::Task>

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=head1  COPYRIGHT

Copyright 2012 (Gavin Alexander)

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module

=cut

# vi: set ts=4 sw=4:
# vi: set expandtab:
