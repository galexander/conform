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


=head2  site

=cut

has 'site' => (
    is  => 'rw',
    isa => 'Conform::Site',
    required => 1,
);

has 'scheduler' => (
    is => 'rw',
    isa => 'Conform::Scheduler',
    default => sub { Conform::Scheduler->new(executor => $_[0]) },
);

=head2  init

=cut

sub init {
    my $self = shift;

    Trace;
    
    $self->runtime->boot;
    $self->compile;
}

sub iam {
    return $_[0]->runtime->iam;
}

sub node {
    return $_[0]->nodes->{$_[0]->iam};
}

sub find_node {
    return $_[0]->nodes->{$_[1]};
}

sub nodes {
    return $_[0]->site->nodes;
}

sub schedule {
    my ($self, $name, $action) = @_;

    Trace "%s %s", $name, $action;

    Debug("scheduling action @{[$name]} -> @{[ dump($action) ]}");

    $self->scheduler->schedule($action);
}

sub merge_node_changes {
    my $self = shift;
    my ($new, $cur) = @_;

    Trace;

    my @actions = ();

    my $cur_isa = $cur->{ISA} || {};
    my $new_isa = $new->{ISA} || {};

    sub _contains {
        my ($haystack, $needle) = @_;
        return grep /^$needle$/, @$haystack;
    }

    sub _subtract {
        my ($a, $b) = @_;
        if (ref $a eq 'HASH' && ref $b eq 'HASH') {
            my @diff = ();
            for (keys %$b) {
                unless (exists $a->{$_}) {
                    push @diff, $b->{$_};
                }
            }
            return @diff;
        }
        if (ref $a eq 'ARRAY' && ref $b eq 'ARRAY') {
            my @diff = ();
            unless (scalar @$a == scalar @$b) {
                for (my $i = scalar @$a; $i < scalar @$b; $i++) {
                    push @diff, $b->[$i];
                }
            }
            return @diff;
        }
    }

    my @isa = ref $new_isa eq 'ARRAY'
                ? @$new_isa
                : [keys %$new_isa];

    for my $isa (@isa) {
        unless (_contains(
                    (ref $cur_isa eq 'HASH'
                        ? [keys %$cur_isa]
                        : $cur_isa),
                    $isa)) {

            $self->extract_node_actions($isa);
        }
    }

    for my $key (keys %$new) {
        unless (exists $cur->{$key}) {
            $self->identify_action($key, $key => $new->{$key});
        } else {
            for (_subtract $cur->{$key}, $new->{$key}) {
                print "key=$key\n";
                $self->identify_action($key, $key => $_);
            }
        }
    }
}

sub execute {
    my ($self, $action) = @_;

    Trace;

    no warnings 'once';
    local $Storable::Deparse = 1;
    my $copy = dclone $self->node;

    $action->execute($self);

    $self->merge_node_changes($self->node, $copy);

}

sub identify_action {
    my $self = shift;
    my $name = shift;
    my $tag  = shift;
    my $value = shift;
    $log->debug("identifying task $tag");
    my $provider = $self->runtime->find_provider(Action => $tag);
    if ($provider) {
        Debug "found provider %s for %s with %s tag = %s",
               dump($provider),
               $name,
                dump($value),
               $tag;

        my @actions  = $provider->actions($self, $tag,  $value);

        $self->schedule($tag, $_)
            for @actions;

        return wantarray 
                   ? @actions
                   :\@actions;
    }
}


sub extract_actions {
    my $self = shift;
    my $name = shift;
    my $hash = shift;

    $log->debug("extract_actions for $name");
    my @actions = ();
    for my $tag (grep !/ISA/, keys %$hash) {
        push @actions, $self->identify_action($name, $tag => $hash->{$tag});
    }
    return wantarray 
            ? @actions
            :\@actions;
}

sub extract_node_actions {
    my $self = shift;
    my $node = shift;

    Trace;

    $self->site->walk
            ($node, sub { $self->extract_actions (@_) });
}

sub compile {
    my $self = shift;
    
    Trace;

    $self->extract_node_actions($self->iam);

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
