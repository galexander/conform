package Conform::Runtime;
use strict;
use attributes ();
use Mouse;
use Module::Pluggable::Object;
use Conform::Role::Task;
use Conform::Role::Action;
use Scalar::Util qw(refaddr);

use Conform::Logger qw($log);

=head1  NAME

Conform::Runtime

=head1  SYNSOPSIS

use Conform::Runtime;

=head1  DESCRIPTION

=cut

=head1  CONSTRUCTOR

=head2  BUILD

=cut

=head1   ACCESSOR METHODS

=head2    name

=cut

has 'name',    ( is => 'rw' );


=head2   data

=cut

has 'data',    ( is => 'rw' );

=head2  tasks

=cut

has 'tasks', (
    is  => 'rw',
    isa => 'HashRef',
    default => sub { {} },
);

=head2  actions

=cut

has 'actions', (
    is  => 'rw',
    isa => 'HashRef',
    default => sub { {} },
);

=head2  plugin_search_dirs

=cut

has 'plugin_search_dirs', (
    is  => 'rw',
    isa => 'ArrayRef',
);


=head2  plugin_search_paths

=cut

has 'plugin_search_paths', (
    is  => 'rw',
    isa => 'ArrayRef',
);

=head1  OBJECT METHODS

=head2  id

=cut

sub id { $_[0]->name }

=head2   execute

=cut

sub execute {
    my $self = shift;
    my $executable = shift;

    $executable->execute($self, $executable, @_)
        if $executable->can(qw(execute));
}

sub define_task {
    my $self = shift;
    my $task = shift;
    $log->debugf("Defining 'Task' with name %s", $task->name);
    $self->tasks->{$task->name} = $task;
}

sub define_action {
    my $self   = shift;
    my $action = shift;
    $log->debugf("Defining 'Action' with name %s", $action->name);
    $self->actions->{$action->name} = $action;
}

sub define {
    my $self    = shift;
    my $type    = shift;
    my $object  = shift;

    return $self->define_task  ($object) if $type eq 'Task';
    return $self->define_action($object) if $type eq 'Action';

    $log->error("Error defining $type (unknown)");
}

sub load_plugins {
    my $self = shift;
    my $name = ref $self;

    $log->debugf("%s->load()", $name);
    
    my @plugin_search_paths;
    my @plugin_search_dirs;

    push @plugin_search_paths, sprintf("%s::Plugin", $name);
    push @plugin_search_paths, sprintf("%s::Plugin", __PACKAGE__);
    push @plugin_search_paths, @{$self->plugin_search_paths || []};
    $log->debugf("plugin_search_paths %s", join ",", @plugin_search_paths);

    push @plugin_search_dirs, @{$self->plugin_search_dirs || []};
    $log->debugf("plugin_search_dirs %s", join ",", @plugin_search_dirs);

    local @INC = @INC;
    push @INC, @plugin_search_dirs;

    my $finder  = Module::Pluggable::Object->new (
                        search_path  => \@plugin_search_paths,
                        search_dirs  => \@plugin_search_dirs
                  );
                    
    my @plugins = $finder->plugins;
    PLUGIN: for my $plugin (@plugins) {
        $log->debug("Loading plugin from $plugin");

        eval {
            eval <<EOREQ;
require $plugin;
EOREQ
            if (my $err = $@) {
                die $err;
            }

            sub _get_type_names {
                my ($type, $field, @list) = @_;

                my @names = ();

                ATTR: for my $attr (@list) {
                    if ($attr =~ /^\Q$type\E(?!\((\S+)\))?$/) {
                        my $name = $1 || $field;
                        push @names, $name
                            unless grep /^$name$/, @names;
                    }
                }

                if ($field =~ s/_\Q$type\E$//) {
                    push @names, $field
                        unless grep /^$field$/, @names;
                }

                return @names;
            }

            next PLUGIN
                if $plugin->can('supported_runtime')
                        and !$plugin->supported_runtime($self);

            no strict 'refs';
            for my $field (keys %{"${plugin}\::"}) {
                next unless defined \&{"${plugin}\::${field}"};
                my @attr = attributes::get(\&{"${plugin}\::${field}"});

                for my $type (qw(Task Action)) {
                    for my $name (_get_type_names $type, $field, @attr) {
                        $log->debugf("%s::%s is a '%s'", $plugin, $name, $type);

                        my $thing = sprintf "Conform::%s", $type;
                        my $executable = $thing->new(name => $name, impl => \&{"${plugin}\::${field}"});

                        $self->define ($type => $executable);
                        
                    }
                }
            }
        };
        if (my $err = $@) {
            $log->error("Error loading plugin $plugin: $@");
        }
    }
}

sub implements {
    my $self = shift;
    my $name = shift;

    return $self->tasks->{$name}   if exists $self->tasks->{$name};
    return $self->actions->{$name} if exists $self->actions->{$name};
    undef;
}

my %attrs = ();

sub MODIFY_CODE_ATTRIBUTES {
    my ($package, $subref, @attrs) = @_;
    $attrs{ refaddr $subref } = \@attrs;
    ();
}

sub FETCH_CODE_ATTRIBUTES {
    my ($package, $subref) = @_;
    my $attrs = $attrs{ refaddr $subref };
    return @{$attrs || [] };
}

__PACKAGE__->meta->make_immutable;

=head1  SEE ALSO

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

1;

# vi: set ts=4 sw=4:
# vi: set expandtab:
