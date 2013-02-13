package Conform::Action;
use Mouse;
use Conform::Logger qw($log);
use Data::Dump qw(dump);
use attributes;

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
    is => 'rw',
);

=item B<execute>

    $action->execute();

=cut

sub execute {
    my $self = shift;
    my $function = $self->impl;
    my @result   = $function->($self->args,
                               $self,
                               @_);
    $self->result(\@result);
    $self->complete(1);
}

=item B<satisfies>

    $action->satisfies($dependency);

=cut

sub satisfies {
    my $self = shift;
    my $dependency = shift;
    my $checked = 0;
    if (exists $dependency->{name}) {
        $checked++; 
        if ($self->name ne $dependency->{name}) {
            return 0;
        }
    }
    if (exists $dependency->{id}) {
        $checked++;
        if (defined $self->id) {
            if ($self->id ne $dependency->{id}) {
                return 0;
            }
        }
    }

    return $checked;
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
