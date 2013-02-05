package Conform::Scheduler;
use Mouse;
use Conform::Queue;
use Data::Dumper;
use Conform::Debug qw(Debug);

#$Conform::Debug::DEBUG++;
$Data::Dumper::Deparse++;

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

=item * actions

Returns true if there are outstanding actions in the 'pending' queue,
false otherwise.

=back

=cut

sub actions {
    my $self = shift;
    return $self->pending->size() > 0;
}
=over 4

=item * schedule

Schedule an action to be executed.
Executes any 'waiting' actions prior to being scheduled.

=cut


sub schedule { Debug "schedule(@{[Dumper($_[1])]})";
    my $self   = shift;
    my $action = shift;

    $self->pending->enqueue($action);

    Debug "schedule - pending = %d, waiting = %d, completed = %d, runnable = %d\n",
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

sub wait { Debug "wait(@{[ Dumper ($_[1]) ]}";
    my $self   = shift;
    my $action = shift;
    $self->waiting->enqueue($action);
}

=over 4

=item * find_waiting

Find all actions 'waiting' for this action.

=back

=cut

sub find_waiting { Debug "find_waiting(@{[Dumper($_[1])]})";
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

sub find_dependency { Debug "find_dependency(@{[Dumper($_[1])]})";
    my $self       = shift;
    my $dependency = shift;

    my $found;

    Debug "searching completed queue";
    $found = $self->completed->find(
        single => sub {
            shift->satisfies($dependency);
        });

    if ($found) {
        return $found;
    }

    Debug "searching pending queue";
    $found = $self->pending->extract(
        single => sub {
            shift->satisfies($dependency);
        });

    if ($found) {
        return $found;
    }


    #Debug "searching waiting queue";
    #$found = $self->waiting->extract(
    #    single => sub {
    #        shift->satisfies($dependency);
    #    });

    Debug "searching runnable queue";
    $found = $self->runnable->extract(
        single => sub {
            shift->satisfies($dependency);
        });


    return $found;
}

sub complete { Debug "complete(@{[Dumper($_[1])]})";
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

sub run { Debug "run()";
    my $self = shift;
    while ($self->actions) {
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

sub execute { Debug "execute(@{[ $_[1]->name ]})";
    my $self   = shift;
    my $action = shift;
    
    # Put action on runnable queue
    $self->runnable->enqueue($action);

    Debug "pre execute - pending = %d, waiting = %d, completed = %d, runnable = %s\n",
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
    Debug "executing %s %s\n", $action->id, $action->name;
    $action->execute();

    $self->runnable->remove($action);

    # Move action to the 'completed' queue
    $self->complete($action);

    Debug "post execute - pending = %d, waiting = %d, completed = %d, runnable = %s\n",
        $self->pending->size,
        $self->waiting->size,
        $self->completed->size,
        $self->runnable->size;
}


1;
