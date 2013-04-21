package Conform::Data::Plugin;
use Mouse;

extends 'Conform::Plugin';

use Conform::Core qw();
use Conform::Data;
use Storable qw(dclone);
use Conform::Debug qw(Trace Debug);
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

    Trace;

    my $work_impl = sub {
        return $self->impl->(@_);
    };

    return Conform::Data->new(name => $tag, impl => $work_impl, provider => $self);
}

1;
