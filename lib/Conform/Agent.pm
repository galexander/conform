package Conform::Agent;
use strict;
use Carp qw(croak);
use Mouse;
use Conform::Site;
use Conform::Logger qw($log);
use Data::Dump qw(dump);
use Conform::Scheduler;
use Conform::Debug qw(Trace Debug);
use Conform::Action;
use Storable qw(dclone);


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

=item   implementation of and actions

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


has 'scheduler' => (
    is => 'rw',
    isa => 'Conform::Scheduler',
    default => sub { Conform::Scheduler->new() },
);

=head2  site

=cut

has 'site' => (
    is  => 'rw',
    isa => 'Conform::Site',
    required => 1,
);

=head2  init

=cut

sub init {
    my $self = shift;

    Trace;
    
    $self->runtime->boot;

    $self->compile;
}

sub schedule {
    my $self = shift;
    my $name = shift;
    my $action = shift;

    Trace "%s %s", $name, $action;

    Debug("scheduling action @{[$name]} -> @{[ dump($action) ]}");

    $self->scheduler->schedule($action);
}

sub identify_action {
    my $self = shift;
    my $name = shift;
    my $hash = shift;

    $log->debug("identify_action for $name");
    for my $tag (grep !/ISA/, keys %$hash) {
        my $value = $hash->{$tag};
        $log->debug("identifying task $tag");

        my $provider = $self->runtime->find_provider(Action => $tag);
        if ($provider) {

            Debug "found provider %s for %s with %s tag = %s",
                   dump($provider),
                   $name, dump($value),
                   $tag;

            my @action  = $provider->actions($self, $tag,  $value);

            $self->schedule($tag, $_)
                for @action;
        
        }
    }
}

sub compile {
    my $self = shift;
    
    Trace;

    my $site    = $self->site;
    my $runtime = $self->runtime;

    $self->site->walk
            ($self->runtime->iam, sub { $self->identify_action (@_) });
}

sub conform {
    my $self = shift;

    Trace;

    Debug "Scheduler has %d jobs", $self->scheduler->pending->size;

    while ($self->scheduler->has_work) {
        $self->scheduler->run();
    }

    Debug "Scheduler has %d pending jobs",   $self->scheduler->pending->size;
    Debug "Scheduler has %d waiting jobs",   $self->scheduler->waiting->size;
    Debug "Scheduler has %d completed jobs", $self->scheduler->completed->size;
    Debug "Scheduler has %d runnable jobs",  $self->scheduler->runnable->size;

}

=head1  SEE ALSO

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

1;

# vi: set ts=4 sw=4:
# vi: set expandtab:
