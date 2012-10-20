package Conform::Agent;
use strict;
use Carp qw(croak);
use Mouse;
use Conform::Site;
use Conform::Logger qw($log);
use Data::Dump qw(dump);
use Conform::Task::Queue;

=head1  NAME

Conform::Agent

=head1  SYNSOPSIS

use Conform::Agent;

my $agent = Conform::Agent->new(
     runtime => $runtime,
     site    => $site
);

=head1  DESCRIPTION

A B<Conform::Agent> is what manages the conform process for a machine.
It uses a definitions provided by a L<Conform::Site> to execute 
functionality provided by a L<Conform::Runtime>

A Conform::Runtime provides
=over 4

=item   implementation of tasks and actions

=item   implementation of data resolvers

=item   execution and state management

=back

A Conform::Site is responsible for providing the defintion for 
=over 4

=item the runtime that this agent is responsible for

=item required functionality in the form of actions and tasks

=item resources - files, variables, plugins, global variables


=back


=cut


=head1  CONSTRUCTOR

=head2 BUILD

=cut

sub BUILD {
    my $self = shift;
    $self->init;
    $self;
}


=head1  ACCESSOR METHDOS

=head2  runtime

=cut

has 'runtime' => (
    is  => 'rw',
    isa => 'Conform::Runtime',
    required => 1,
);

=head2  site

=cut

has 'site' => (
    is  => 'rw',
    isa => 'Conform::Site',
    required => 1,
);

=head2  tasks

=cut

has 'tasks' => (
    is => 'rw',
    isa => 'Conform::Task::Queue',
    default => sub { Conform::Task::Queue->new() }
);

has 'unscheduled_tasks' => (
    is => 'rw',
    isa => 'Conform::Task::Queue',
    default => sub { Conform::Task::Queue->new() }
);


=head2  init

=cut

sub init {
    my $self = shift;
    
    my $runtime = $self->runtime;
    my $site    = $self->site;

    $self->compile_task_queue;

}

sub schedule {
    my $self = shift;
    my $task = shift;
    my $data = shift;
    $log->debug("scheduling task @{[$task]} -> @{[ dump($data) ]}");

    my $tasks   = $self->tasks;
    my $runtime = $self->runtime;

    $log->debug("determining if @{[ ref $runtime ]} implements $task");
    if ($runtime->implements ($task)) {
        $log->debug("@{[ ref $runtime ]} implements $task");

    }

}

sub identify_tasks {
    my $self = shift;
    my $name = shift;
    my $hash = shift;

    $log->debug("identify_tasks for $name");
    for my $tag (grep !/ISA/, keys %$hash) {
        my $value = $hash->{$tag};
        $log->debug("identifying task $tag");

        $self->schedule($tag => $value);
        
    }
}

sub compile_task_queue {
    my $self = shift;
    $log->debug("compile_task_queue");

    my $site    = $self->site;
    my $runtime = $self->runtime;

    # collect all tasks

    $site->walk($runtime->id,  sub { $self->identify_tasks (@_) });

}

sub conform {
    my $self = shift;


}


=head1  SEE ALSO



=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

1;

# vi: set ts=4 sw=4:
# vi: set expandtab:
