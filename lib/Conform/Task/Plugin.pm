package Conform::Task::Plugin;
use Moose;

extends 'Conform::Work::Plugin';

use Conform::Core qw();
use Conform::Task;
use Storable qw(dclone);
use Conform::Logger qw($log trace debug notice warn fatal);
use Data::Dump qw(dump);
use Conform::Plugin;
use Conform;

our $VERSION = $Conform::VERSION;

sub import {
    my $package = shift;
    my $caller  = caller;
    __PACKAGE__->SUPER::import (package => $caller);
}

sub factory {
    my ($self, $agent, $tag, $args) = @_;

    trace;

    my $work_impl = sub {
        return $self->impl->(@_);
    };

    return Conform::Task->new(name => $tag, impl => $work_impl, provider => $self);
}

1;
