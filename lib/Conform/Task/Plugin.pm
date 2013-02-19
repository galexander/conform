package Conform::Task::Plugin;
use Mouse;

extends 'Conform::Work::Plugin';

use Conform::Core qw();
use Conform::Task;
use Storable qw(dclone);
use Conform::Debug qw(Trace Debug);
use Data::Dump qw(dump);
use Conform::Plugin;

sub import {
    my $package = shift;
    my $caller  = caller;
    __PACKAGE__->SUPER::import (package => $caller);
}

sub factory {
    my ($self, $agent, $tag, $args) = @_;

    Trace;

    my $name = $self->name;

    my $work_impl = sub {
        return $self->impl->(@_);
    };

    return Conform::Task->new(name => $tag, impl => $work_impl, provider => $self);
}

1;
