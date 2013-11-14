package Conform::Data::Plugin;
use Moose;

extends 'Conform::Plugin';

use Conform::Core qw();
use Conform::Data;
use Storable qw(dclone);
use Data::Dump qw(dump);
use Conform::Plugin;
use Conform;
use Conform::Logger qw($log trace debug notice warn fatal);

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

    return Conform::Data->new(name => $tag, impl => $work_impl, provider => $self);
}

1;
