package Conform::Scheduler;
=head1  NAME

Conform::Scheduler

=head1  SYNOPSIS

    use Conform::Scheduler;
    
    my $scheduler = Conform::Scheduler->new();

    $scheduler->schedule($action);

    while ($scheduler->actions) {
        $scheduler->run();
    }


=head1  DESCRIPTION

Generic 'Conform::Action' scheduler/executor with dependency resolution

=head1  METHODS
    
=cut

use Mouse;
use Conform::Queue;
use Data::Dumper;
use Conform::Debug qw(Debug Trace);

has 'pending'   => (
    is      => 'rw',
    isa     => 'Conform::Queue',
    default => sub { new Conform::Queue() }
);

has 'waiting'   => (
    is      => 'rw',
    isa     => 'Conform::Queue',
    default => sub { new Conform::Queue() }
);

has 'completed'   => (
    is      => 'rw',
    isa     => 'Conform::Queue',
    default => sub { new Conform::Queue() }
);

has 'runnable' => (
    is      => 'rw',
    isa     => 'Conform::Queue',
    default => sub { new Conform::Queue() }
);

=over 4

=item * has_work 

Returns true if there are outstanding actions in the 'pending' queue,
false otherwise.

=back

=cut

sub has_work {
    my $self = shift;
    return $self->pending->size() > 0;
}
=over 4

=item * schedule

Schedule an action to be executed.
Executes any 'waiting' actions prior to being scheduled.

=back

=cut


sub schedule { Trace "schedule(@{[Dumper($_[1])]})";
    my $self   = shift;
    my $action = shift;

    $self->pending->enqueue($action);

    Trace "schedule - pending = %d, waiting = %d, completed = %d, runnable = %d\n",
        $self->pending->size,
        $self->waiting->size,
        $self->completed->size,
        $self->runnable->size;
}

=over 4

=item * wait

Place an action on the waiting queue.
When an action is scheduled or executed
that satisfies the outstanding dependency then this action
will be run.

=back

=cut

sub wait { Trace "wait(@{[ Dumper ($_[1]) ]}";
    my $self   = shift;
    my $action = shift;
    $self->waiting->enqueue($action);
}

=over 4

=item * find_waiting

Find all actions 'waiting' for this action.

=back

=cut

sub find_waiting { Trace "find_waiting(@{[Dumper($_[1])]})";
    my $self   = shift;
    my $action = shift;

    my @found = $self->waiting->extract(
        multi => sub {
            my $dependencies = $_->dependencies;
            for my $dependency (@$dependencies) {
                if ($action->satisfies($dependency)) {
                    return 1;
                }
            }
            return 0;
        });

    push @found, $self->runnable->extract(
        multi => sub {
            my $dependencies = $_->dependencies;
            for my $dependency (@$dependencies) {
                if ($action->satisfies($dependency)) {
                    return 1;
                }
            }
            return 0;
        });

    return @found;
}


=over 4

=item * find_depenency

Find pending or completed action that satisfies
an action dependency.

=back

=cut

sub find_dependency { Trace "find_dependency(@{[Dumper($_[1])]})";
    my $self       = shift;
    my $dependency = shift;

    my $found;

    Trace "searching completed queue";
    $found = $self->completed->find(
        single => sub {
            shift->satisfies($dependency);
        });

    if ($found) {
        return $found;
    }

    Trace "searching pending queue";
    $found = $self->pending->extract(
        single => sub {
            shift->satisfies($dependency);
        });

    if ($found) {
        return $found;
    }


    Trace "searching runnable queue";
    $found = $self->runnable->extract(
        single => sub {
            shift->satisfies($dependency);
        });


    return $found;
}

sub complete { Trace "complete(@{[Dumper($_[1])]})";
    my $self   = shift;
    my $action = shift;

    $action->complete(1);

    $self->completed->enqueue($action);

    # Execute waiting after we've executed
    my @waiting = $self->find_waiting ($action);

    for my $waiting (@waiting) {
        $self->execute($waiting)
    }
}

sub run { Trace "run()";
    my $self = shift;
    while ($self->has_work) {
        my $action = $self->pending->dequeue();
        $self->execute($action);
    }
}


=over 4

=item * execute

Execute an action. Ensure that dependencies are satisfied.
Also executes actions 'waiting' for this action.

=back

=cut

sub execute { Trace "execute(@{[ $_[1]->name ]})";
    my $self   = shift;
    my $action = shift;
    
    # Put action on runnable queue
    $self->runnable->enqueue($action);

    Trace "pre execute - pending = %d, waiting = %d, completed = %d, runnable = %s",
        $self->pending->size,
        $self->waiting->size,
        $self->completed->size,
        $self->runnable->size;

    # Find all dependencies
    my $dependencies = $action->dependencies;
    for my $dependency (@$dependencies) {
        my $found = $self->find_dependency ($dependency);
        if ($found) {
            unless($found->complete) {
                # Execute found (not complete) actions
                return $self->execute($found);
            }
        } else {
            # Hold off until we execute an action that can
            # satisfy this dependency
            $self->runnable->remove($action);
            $self->wait($action);
            return;
        }
    }

    # Execute the action (This can call 'schedule' as well)
    Trace "executing %s %s", $action->id, $action->name;
    $action->execute();

    $self->runnable->remove($action);

    # Move action to the 'completed' queue
    $self->complete($action);

    Trace "post execute - pending = %d, waiting = %d, completed = %d, runnable = %s",
        $self->pending->size,
        $self->waiting->size,
        $self->completed->size,
        $self->runnable->size;
}


1;
