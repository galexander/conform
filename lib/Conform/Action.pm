package Conform::Action;
use Mouse;
use Data::Dump qw(dump);
use Conform;
use Conform::Logger qw($log);
use Conform::Debug qw(Trace Debug);

our $VERSION = $Conform::VERSION;

extends 'Conform::Work';

=head1  NAME

Conform::Action - descrete unit of work to be run by a conform agent.

=head1  SYNSOPSIS

use Conform::Action;

=head1  DESCRIPTION

=cut

=head1  METHODS

=over

=item B<run>

    $action->run();

=cut

sub run {
    my $self     = shift;

    Trace;

    Debug "Executing Action (id=%s,name=%s,args=%s)",
          $self->id,
          $self->name,
          dump($self->args);


    my $function = $self->impl;
    my @result   = $function->($self->args,
                               $self,
                               @_);

    Debug "Action (id=%s,name=%s,args=%s) returned %s",
          $self->id,
          $self->name,
          dump($self->args),
          dump(\@result);

    return wantarray
            ? @result
            :\@result;
}


=item B<args>

    $args = $action->args;

=cut

has 'args' => (
    is => 'rw',
    required => 1,
);

=back

=head1  SEE ALSO

=over 4

=item

L<Conform::Work>

=item

L<Conform::Task>

=item

L<Conform::Action::Plugin>

=back

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
