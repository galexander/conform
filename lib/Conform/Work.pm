package Conform::Work;
use Mouse;
use Data::Dump qw(dump);
use Conform::Logger qw($log);
use Conform::Debug qw(Trace Debug);
use Scalar::Util qw(blessed);
use Carp qw(croak);

=head1  NAME

Conform::Work

=head1  SYNSOPSIS

package Conform::Action;  extends 'Conform::Work';
pakcage  Conform::Task;   extends 'Conform::Work';

=head1 ABSTRACT

Conform::Work - descrete unit of work to be run by a conform agent.

=head1  DESCRIPTION

=cut

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

sub merge_directives {
    my $self = shift;
    my @directives = @_;
    my $directive_map = $self->directive_map;
    for my $directive (@directives) {
        $log->tracef("Directive=%s", dump($directive));
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

=cut

has 'provider' => (
    'is' => 'rw',
);

=item B<directive_map>

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

=item B<directives>

=cut

has 'directives' => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { [] },
);


=item B<attr>

=cut

sub attr {
    my $self = shift;
    $self->provider->attr;
}

=item B<constraint>

    
    my $constraint = $work->constraint();

=cut

has 'constraint' => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
);

has 'locked' => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
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
