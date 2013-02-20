package Conform::Work;
use Mouse;
use Data::Dump qw(dump);
use Conform::Logger qw($log);
use Conform::Debug qw(Trace Debug);
use Scalar::Util qw(blessed);
use Carp qw(croak);

use constant MIN_PRIO     => 100;
use constant LOW_PRIO     => 75;
use constant MAX_PRIO     => 1;
use constant HIGH_PRIO    => 25;
use constant DEFAULT_PRIO => 50;

=encoding utf-8

=head1  NAME

Conform::Work - Descrete unit of work to be run by a conform agent.


=head1  SYNSOPSIS

    # Creating new work types
    package Conform::Action;
          extends 'Conform::Work';

    package Conform::Task; 
          extends 'Conform::Work';

    ...
    ...

    # Using new work types
    my $job = Conform::Action->new(name => 'name',
                                   impl => \&coderef);

    $job->name('foo');
    my $name = $job->name;

    $job->id('bar');
    my $id = $job->id;

    $job->prio(10);
    my $prio = $job->prio;

=head1  DESCRIPTION

Conform::Work is an abstract class to be extended.

At its core Conform::Work is A job, or unit of work to be executed by a 
conform agent as specified by a conform node definition.

Conform::Work is a proxy for plugins, provided by L<Conform::Action>'s
and L<Conform::Task>'s.

Conform::Work provides attributes for

=over

=item 

work identification with names and id's. 

=item 

hints for work scheduling through dependencies, and prioroties.

=back

=cut

=head1  CONSTRUCTOR

N/A

=head1  METHODS

=cut

sub BUILD {
    my $self = shift;
    blessed $self eq __PACKAGE__
        and croak "@{[__PACKAGE__]} is abstract";

    my $attr       = $self->attr;
    my $directives = $self->directives;

    Debug "attr = @{[dump($attr)]}";
    Debug "directives = @{[dump($directives)]}";

    $self->merge_directives(@$attr, @$directives);

    Debug "dependencies = %s\n", $self->dependencies;

    $self;
}

=head2 B<name>

    $name = $work->name;
    $work->name($name);

=cut

has 'name' => (
    is => 'rw',
);


=head2 B<id>

    $id = $work->id;
    $work->id($id);

=cut

has 'id' => (
    is => 'rw',
);


=head2 B<prio>

    $work->prio;

=cut

has 'prio' => (
    is => 'rw',
    isa => 'Int',
    default => '50',
);

=head2 B<complete>

    $complete = $work->complete;

=cut
    
has 'complete' => (
    is => 'rw',
    isa => 'Bool',
);

=head2 B<result>
    
    $result = $work->result;

=cut

has 'result' => (
    'is' => 'rw',
);

=head2 B<impl>
    
    $work->impl->();

=cut

has 'impl' => (
    is  => 'rw',
    isa => 'CodeRef',
    required => 1,
);

=head2 B<dependencies>

    $dependencies = $action->dependencies;
    $action->dependencies(\@dependencies);

=cut

has 'dependencies' => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { [] },
);

=head2 B<provider>

=cut

has 'provider' => (
    'is' => 'rw',
);

=head2 B<directive_map>

=cut

has 'directive_map' => (
    is  => 'rw',
    isa => 'HashRef',
    default => sub {
        {
            'Version'  => 'version',
            'Id'       => 'id',
            'Name'     => 'name',
            'Action'   => 'name',
            'Task'     => 'name',
            'Prio'     => 'prio',
            'Priority' => 'prio',
        }
    },
);

=head2 B<directives>

=cut

has 'directives' => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { [] },
);


=head2 B<attr>

=cut

sub attr {
    my $self = shift;
    $self->provider->attr;
}

=head2 B<constraints>

    my $constraints = $work->constraints();

=cut

has 'constraints' => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
);

has 'locked' => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);

=head2 B<execute>

    $work->execute();

=cut

sub execute {
    my $self     = shift;

    Debug "Executing Work (id=%s,name=%s)",
                $self->id,
                $self->name;

    my @result   = $self->run(@_);

    Debug "Work (id=%s,name=%s) returned %s",
          $self->id,
          $self->name,
          dump(\@result);

    $self->result(\@result);

    $self->complete(1);

    return wantarray
            ? @result
            :\@result;
}

=head2 B<satisfies>
    
    $work->satisfies($dependency);

=cut

sub satisfies { Trace;
    my $self       = shift;
    my $dependency = shift;

    if (ref $dependency eq 'HASH') {

        for my $check (keys %$dependency) {

            if ($check =~ /^\.(\S+)/) {
                my $param = $1;

                if ($self->can($param)
                    && defined $self->$param()
                    && ($dependency->{$check} eq $self->$param())) {

                    Debug "Work (id=%s,name=%s) satisfies dependency %s=%s",
                          $self->id,
                          $self->name,
                          $check,
                          dump($dependency->{$check});

                    delete $dependency->{$check};
                }
            }
        }

        if (keys %$dependency) {
            Debug "Unmet dependencies @{[ dump ($dependency) ]}";
            return 0;
        } else {
            Debug "All dependencies met";
            return 1;
        }
    }

    return 0;
}

=head2  merge_directives

=cut

sub merge_directives {
    my $self = shift;
    my @directives = @_;
    my $directive_map = $self->directive_map;
    for my $directive (@directives) {
        my %hash = ref $directive eq 'HASH'
                    ? %$directive
                    : ($directive->[0] => $directive->[1]);

        for my $keyword (keys %hash) {
            my $arg    = $hash{$keyword};
            my $method = $hash{$keyword} || $keyword;
            if ($self->can($method) && defined $arg) {
                $self->$method($arg);
            }

            if ($keyword eq 'depend') {
                my $dependencies = $self->dependencies;
                if ($arg =~ /^(\S+?)(?:\[(.*)\])$/) {
                    push @$dependencies,
                            { '.name' => $1, '.id' => $2 };
                }
            }
        }
    }
}



1;

=back

=head1  SEE ALSO

L<conform> L<Conform::Action> L<Conform::Task>

=head1  TODO

=over

=item

Maybe make this a 'Mouse;:Role' and create  'Conform::Job' abstract
class and move the stateful functionality to it.

=item

Make private things private

=item

enforce 'locked' - maybe at a 'commit' function to enforce 'frozen' state.

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

# vi: set ts=4 sw=4:
# vi: set expandtab:
