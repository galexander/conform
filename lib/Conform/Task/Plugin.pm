package Conform::Action::Plugin;
use Mouse;

extends 'Conform::Plugin';

use Conform::Core qw();
use Conform::Action;
use Storable qw(dclone);
use Conform::Debug qw(Trace Debug);
use Data::Dump qw(dump);
use Conform::Plugin;

sub import {
    my $package = shift;
    my $caller  = caller;

    no strict 'refs';
    *{"${caller}\::Action"}         = \&Action;
    *{"${caller}\::PushAction"}     = \&PushAction;
    *{"${caller}\::MergeAction"}    = \&MergeAction;
    *{"${caller}\::i_isa"}          = \&i_isa;
    *{"${caller}\::i_isa_fetchall"} = \&i_isa_fetchall;
    *{"${caller}\::i_isa_mergeall"} = \&i_isa_mergeall;

    __PACKAGE__->SUPER::import (package => $caller);
}

has 'id'        => ( is => 'rw', isa => 'Str' );
has 'name'      => ( is => 'rw', isa => 'Str' );
has 'impl'      => ( is => 'rw', isa => 'CodeRef' );
has 'version'   => ( is => 'rw', isa => 'Str');

sub task {
    my ($self, $agent, $tag, $args) = @_;

    Trace;

    my $name = $self->name;

    my $work_impl = sub {
        return $self->impl->(@_);
    };

    return Conform::Task->new(name => $tag, impl => $work_impl);
}

sub get_agent {
    my $context = Conform::Work->getExecutionContext();
    my $provider = $context->provider;
    return $provider->agent;
}

sub Action {
    my ($runtime, $site);
    my $agent = __PACKAGE__->get_agent;
    if (blessed $_[0]
         and $_[0]->isa('Conform::Action')) {
            ($runtime, $site) = ($_[0]->provider->runtime, $_[0]->provider->site);
            shift;
    } else {
        ($runtime, $site) = ($agent->runtime, $agent->site);
    }

    my $action  = shift;
    Debug "Adding action $action\n";
    my $action_val = $site->nodes->{$runtime->iam}{$action};
    unless (defined $action_val) {
        push @{$site->nodes->{$runtime->iam}{$action}}, @_;
    } else {
        push @{$site->nodes->{$runtime->iam}{$action}}, [@_];
    }
}

sub i_isa {
    my ($runtime, $site);
    my $agent = __PACKAGE__->get_agent;
    if (blessed $_[0]
         and $_[0]->isa('Conform::Action')) {
            ($runtime, $site) = ($_[0]->provider->runtime, $_[0]->provider->site);
    } else {
        ($runtime, $site) = ($agent->runtime, $agent->site);
    }
    return Conform::Core::i_isa ($runtime->iam, $site->nodes, @_);
}

sub i_isa_fetchall {
    my ($runtime, $site);
    my $agent = __PACKAGE__->get_agent;
    if (blessed $_[0]
         and $_[0]->isa('Conform::Action')) {
            ($runtime, $site) = ($_[0]->provider->runtime, $_[0]->provider->site);
    } else {
        ($runtime, $site) = ($agent->runtime, $agent->site);
    }
    return Conform::Core::i_isa ($site->nodes, $runtime->iam, @_);
}

sub i_isa_mergeall {
    my ($runtime, $site);
    my $agent = __PACKAGE__->get_agent;
    if (blessed $_[0]
         and $_[0]->isa('Conform::Action')) {
            ($runtime, $site) 
                = ($_[0]->provider->runtime, $_[0]->provider->site);
    } else {
        ($runtime, $site) 
            = ($agent->runtime, $agent->site);
    }

    return Conform::Core::i_isa_mergeall ($site->nodes,
                                          $runtime->iam,
                                          @_);
}

1;
