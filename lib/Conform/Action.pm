package Conform::Action;
use Mouse;
use Data::Dump qw(dump);
use Conform::Logger qw($log);
use Conform::Debug qw(Trace Debug);

=head1  NAME

Conform::Action

=head1  SYNSOPSIS

use Conform::Action;

=head1 ABSTRACT

Conform::Action - descrete unit of work to be run
by a conform agent.

=head1  DESCRIPTION

=cut

=head1  METHODS

=over

=item B<id>

    $id = $action->id;
    $action->id($id);

=cut

has 'id' => (
    is => 'rw',
);

=item B<name>

    $name = $action->name;
    $action->name($name);

=cut

has 'name' => (
    is => 'rw',
    isa => 'Str',
);

=item B<prio>

    $action->prio;

=cut

has 'prio' => (
    is => 'rw',
    isa => 'Int',
    default => '50',
);

=item B<complete>

    $complete = $action->complete;

=cut
    
has 'complete' => (
    is => 'rw',
    isa => 'Bool',
);

=item B<dependencies>

    $dependencies = $action->dependencies;
    $action->dependencies(\@dependencies);

=cut

has 'dependencies' => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { [] },
);

=item B<provider>

    $provider = $action->provider;

=cut

has 'provider' => (
    is => 'rw',
);

=item B<args>

    $args = $action->args;

=cut

has 'args' => (
    is => 'rw',
    required => 1,
);

=item B<result>
    
    $result = $action->result;

=cut

has 'result' => (
    'is' => 'rw',
);

=item B<impl>
    
    $action->impl->();

=cut

has 'impl' => (
    is  => 'rw',
    isa => 'CodeRef',
    required => 1,
);

=item B<execute>

    $action->execute();

=cut

sub execute { Trace;
    my $self     = shift;

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

    $self->result(\@result);

    $self->complete(1);

    return wantarray
            ? @result
            :\@result;
}

=item B<satisfies>

    $action->satisfies($dependency);

=cut


sub _check_args {
    my ($dependency, $args) = @_;

    return 0 unless defined $dependency and
                    defined $args;

    if (!ref $dependency) {
        if (!ref $args) {
            return 1 if $args eq $dependency;
        }

        if (ref $args eq 'HASH') {
            for my $value (grep !ref, values %$args) {
                if ($value eq $dependency) {
                    return 1;
                }
            }
        }
        if (ref $args eq 'ARRAY') {
            if (grep /^\Q$dependency\E$/, @$args) {
                return 1;
            }
        }

    } else {

        if (ref $dependency eq 'HASH') {

            if (!ref $args) {
                return 1 if grep /^\Q$dependency\E$/, values %$args;
            }

            if (ref $args eq 'HASH') {
                for my $check (keys %$dependency) {
                    return 1
                        if (exists $args->{$check} &&
                           ($args->{$check} eq $dependency->{$check}));
                }
            }

            if (ref $args eq 'ARRAY') {
                for my $check (values %$dependency) {
                    return 1
                        if grep /^\Q$check\E$/, values %$args;
                }
            }
        }
    }

    return 0;
}

sub satisfies { Trace;
    my $self       = shift;
    my $dependency = shift;

    Debug "satisfies(%s)", dump($dependency);

    if (ref $dependency eq 'HASH') {

        for my $check (keys %$dependency) {

            if ($check =~ /^action\.(\S+)/) {
                my $param = $1;
                if ($self->can($param) && 
                   ($dependency->{$check} eq $self->$param())) {

                    Debug "Action (id=%s,name=%s,args=%s) satisfies dependency %s",
                          $self->id,
                          $self->name,
                          dump($self->args),
                          dump($dependency);

                    return 1;
                }
            }
        }
    }

    if (_check_args $dependency, $self->args) {
        Debug "Action (id=%s,name=%s,args=%s) satisfies dependency %s",
              $self->id,
              $self->name,
              dump($self->args),
              dump($dependency);
    
            return 1;
    }


    Debug "dependency (%s) - not satisfied";
    return 0;
}

=back


=head1  SEE ALSO

L<conform> L<Conform::Action::Plugin>

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
