package Conform::Scheduler;
=head1  NAME

Conform::Scheduler

=head1  SYNOPSIS

    use Conform::Scheduler;
    
    my $scheduler = Conform::Scheduler->new();

    $scheduler->schedule($work);

    while ($scheduler->work) {
        $scheduler->run();
    }


=head1  DESCRIPTION

Generic 'Conform::Work' scheduler/executor with dependency resolution

=head1  METHODS
    
=cut

use Mouse;
use Conform::Queue;
use Data::Dump qw(dump);
use Conform::Debug qw(Debug Trace);
use Scalar::Util qw(refaddr);
use Conform::Logger qw($log);

has 'executor' => (
    is => 'rw',
    required => 1,
);

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

=item * scheduled

=cut

sub scheduled {
    my $self = shift;
    my $work = shift;

    my $found = $self->pending->find(
                    single => sub {
                        my $job  = shift;
                        return $job if $job->name eq $work->name;
                    });
    
    return $found;

}

=item * has_work 

Returns true if there are outstanding work in the 'pending' queue,
false otherwise.

=back

=cut

sub has_work {
    my $self = shift;
    return $self->pending->size() > 0;
}
=over 4

=item * schedule

Schedule work to be executed.
Executes any 'waiting' work prior to being scheduled.

=back

=cut


sub schedule { Trace "schedule(@{[dump($_[1])]})";
    my $self   = shift;
    my $work   = shift;
    
    my $constraints = $work->constraints;

    my $schedule = 1;

    if (keys %$constraints) {
        if (my $check = $constraints->{unique}) {
            my $existing = $self->pending->find(
                single => sub {
                    my $job = shift;
                    $job->can($check) && $job->$check eq $work->$check;
            });

            $schedule = !$existing;

            Debug "work %s already exists", $work->$check
        }
    }

        
    $self->pending->enqueue($work)
        if $schedule;

    Trace "schedule - pending = %d, waiting = %d, completed = %d, runnable = %d\n",
        $self->pending->size,
        $self->waiting->size,
        $self->completed->size,
        $self->runnable->size;
}

=over 4

=item * wait

Place work on the waiting queue.
When work is scheduled or executed
that satisfies the outstanding dependency then this work
will be run.

=back

=cut

sub wait { Trace "wait(@{[ dump($_[1]) ]}";
    my $self   = shift;
    my $work   = shift;
    $self->waiting->enqueue($work);
}

=over 4

=item * find_waiting

Find all work 'waiting'

=back

=cut

sub find_waiting { Trace "find_waiting(@{[dump($_[1])]})";
    my $self   = shift;
    my $work   = shift;

    my @found = $self->waiting->extract(
        multi => sub {
            my $dependencies = $_->dependencies;
            for my $dependency (@$dependencies) {
                if ($work->can('satisfies') && $work->satisfies($dependency)) {
                    return 1;
                }
            }
            return 0;
        });

    push @found, $self->runnable->extract(
        multi => sub {
            my $dependencies = $_->dependencies;
            for my $dependency (@$dependencies) {
                if ($work->can('satisfies') && $work->satisfies($dependency)) {
                    return 1;
                }
            }
            return 0;
        });

    return @found;
}


=over 4

=item * find_depenency

Find pending or completed work that satisfies
a dependency.

=back

=cut

sub find_dependency { Trace "find_dependency(@{[dump($_[1])]})";
    my $self       = shift;
    my $dependency = shift;

    my $found;

    Trace "searching completed queue";
    $found = $self->completed->find(
        single => sub {
            my $work = shift;
            $work->can('satisfies') && $work->satisfies($dependency);
        });

    if ($found) {
        return $found;
    }

    Trace "searching pending queue";
    $found = $self->pending->extract(
        single => sub {
            my $work = shift;
            $work->can('satisfies') && $work->satisfies($dependency);
        });

    if ($found) {
        return $found;
    }


    Trace "searching runnable queue";
    $found = $self->runnable->extract(
        single => sub {
            my $work = shift;
            $work->can('satisfies') && $work->satisfies($dependency);
        });


    return $found;
}

sub complete { Trace "complete(@{[dump($_[1])]})";
    my $self   = shift;
    my $work   = shift;

    $work->complete(1);

    $self->completed->enqueue($work);

    # Execute waiting after we've executed
    my @waiting = $self->find_waiting ($work);

    for my $waiting (@waiting) {
        $self->execute($waiting)
    }
}

sub run { Trace "run()";
    my $self     = shift;
    while ($self->has_work) {
        my $work = $self->pending->dequeue();
        $self->execute($work);
    }
}


=over 4

=item * execute

Execute work. Ensure that dependencies are satisfied.
Also executes work 'waiting' for this peice of work

=back

=cut

sub execute { Trace "execute(@{[ $_[1]->name ]})";
    my $self     = shift;
    my $work     = shift;
    my $stack    = shift || [];

    for (@$stack) {
        if (refaddr $_ eq refaddr $work) {
            $log->error("Circular dependency detected for id=@{[$work->id]}, name=@{[$work->name]}");
            $log->error("Waiting...");
            for my $waiting (@{$self->waiting->list ||[]}) {
                $log->errorf("waiting: ", $waiting);
            }
            $log->errorf("Runnable...", $self->runnable);
            for my $runnable (@{$self->runnable->list ||[]}) {
                $log->errorf("runnable:$runnable");
            }

            die "dependency resolution error";
        }
    }

    push @$stack, $work;

    # Put work on runnable queue
    $self->runnable->enqueue($work);

    Trace "pre execute - pending = %d, waiting = %d, completed = %d, runnable = %s",
        $self->pending->size,
        $self->waiting->size,
        $self->completed->size,
        $self->runnable->size;

    # Find all dependencies
    my $dependencies = $work->dependencies;
    for my $dependency (@$dependencies) {
        my $found = $self->find_dependency ($dependency);
        Debug "found dependency %s", dump($found);
        if ($found) {
            unless($found->complete) {
                # Execute found (not complete) work
                return $self->execute($found, $stack);
            }
        } else {
            # Hold off until we execute work that can
            # satisfy this dependency
            $self->runnable->remove($work);
            $self->wait($work);
            return;
        }
    }

    # Execute the work (This can call 'schedule' as well)
    Trace "executing %s %s", $work->id, $work->name;
    my $executor = $self->executor;
    if (ref $executor eq 'CODE') {
        $executor->($work);
    } else {
        $executor->execute($work);
    }

    # Remove from runnable queue
    $self->runnable->remove($work);

    # Move work to the 'completed' queue
    $self->complete($work);

    Trace "post execute - pending = %d, waiting = %d, completed = %d, runnable = %s",
        $self->pending->size,
        $self->waiting->size,
        $self->completed->size,
        $self->runnable->size;
}


1;
