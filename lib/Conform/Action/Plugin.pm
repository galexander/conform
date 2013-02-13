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
    *{"${caller}\::named_args"}     = \&named_args;
    *{"${caller}\::i_isa"}          = \&i_isa;
    *{"${caller}\::i_isa_fetchall"} = \&i_isa_fetchall;
    *{"${caller}\::i_isa_mergeall"} = \&i_isa_mergeall;

    __PACKAGE__->SUPER::import (package => $caller);
}

has 'id'        => ( is => 'rw', isa => 'Str' );
has 'name'      => ( is => 'rw', isa => 'Str' );
has 'configure' => ( is => 'rw', isa => 'CodeRef' );
has 'impl'      => ( is => 'rw', isa => 'CodeRef' );
has 'version'   => ( is => 'rw', isa => 'Str');

my $_agent;
sub set_agent { $_agent = $_[1] }
sub get_agent { $_agent }

sub actions {
    my ($self, $agent, $tag, $args) = @_;

    Trace;

    __PACKAGE__->set_agent ($agent)
        unless __PACKAGE__->get_agent;

    my $name = $self->name;

    my $action_impl = sub {
        return $self->impl->(@_);
    };
    
    return () unless defined $args;

    if (ref $args eq 'ARRAY') {
        my @actions = ();
        for my $value (@$args) {
            push @actions,
                 Conform::Action->new('args' => $value,
                                      'name' => $name,
                                      'provider' => $self,
                                      'impl' => $action_impl);
        }
        return @actions;
    }

    if (ref $args eq 'HASH') {
        my @actions = ();
        for my $key (keys %$args) {
            push @actions,
                 Conform::Action->new('args' => {$key => $args->{$key}},
                                      'name' => $name,
                                      'provider' => $self,
                                      'impl' => $action_impl);
        }
        return @actions;
    }

    return (Conform::Action->new('args' => $args,
                                 'name' => $name,
                                 'provider' => $self,
                                 'impl' => $action_impl));

}

sub _actions {
    my $self        = shift;
    my $agent       = shift;
    my $tag         = shift;
    my $value       = shift;

    __PACKAGE__->set_agent($agent);

    my $name    = $self->name();

    return () unless defined $value;

    my $Impl = $self->impl;

    my $_scalar_action = sub {
        my $scalar = shift;
        return Conform::Action->new(
                'args' => $scalar,
                'name' => $name,
                'provider' => $self,
                'impl' => sub {
                    $Impl->($scalar,(shift @_), $agent)
                });
    };

    my $_hash_action = sub {
        my $hash = shift;
        my @action = ();
        for my $id (keys %$hash) {
            my $args    = $hash->{$id}; 
            my $action =
                Conform::Action->new(
                            'id' => $id,
                            'args' => $hash->{$id},
                            'name' => $name,
                            'provider' => $self,
                            'impl' => sub {
                                $Impl->($id,
                                                  $args,
                                                  (shift @_),
                                                  $agent)
                            }
                );

            push @action, $action;
        }

        return @action;
    };

    my $_array_action = sub {
        my $array = shift;

        if (scalar @$array % 2 == 0
                && !ref $array->[0]
                &&  ref $array->[1]
                &&  ref $array->[1] eq 'HASH') {

            my @action = ();

            for (my $i = 0; $i < scalar @$array; $i+=2) {
                my $id = $array->[$i];
                my $args = $array->[$i+1];
                push @action, Conform::Action->new(
                                'id' => $id,
                                'args' => $args,
                                'name' => $name,
                                'provider' => $self,
                                'impl' => sub {
                                    $Impl->($id, $args, (shift @_), $agent)
                                });
            }
    
            return @action;
         }

        return (Conform::Action->new(
                    'id' => undef,
                    'args' => $array,
                    'name' => $self->name(),
                    'provider' => $self,
                    'impl' => sub {
                        $Impl->($array,(shift @_), $agent)
                    }));
    };

    return $_scalar_action->($value)
            if !ref $value;

    return $_hash_action->($value)
            if ref $value eq 'HASH';

    my @return;

    if (ref $value eq 'ARRAY') {
        VALUE: for my $arg (@$value) {
            unless (ref $arg) {
                push @return, $_scalar_action->($arg);
                next VALUE;
            }
            if (ref $arg eq 'HASH') {
                push @return, $_hash_action->($arg);
                next VALUE;
            }
            if (ref $arg eq 'ARRAY') {
                push @return, $_array_action->($arg);
                next VALUE;
            }
        }
    }

    return @return;
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

sub named_args {
    my($params, $defaults) = @_;
    return undef unless $params;
    $params = [ $params ]
        if (ref $params eq 'HASH' || !ref $params);
    return $params->[0] if ref $params->[0] eq 'HASH' && @$params == 1;
    my $return = {};
  
    if (@$params % 2 != 0 || $params->[0] !~ /^-/) {
      # Positional parameters
      my @order;
      for (my $i = 0; $i < @$defaults; $i += 2) {
        my($key, $value) = ($defaults->[$i], $defaults->[$i + 1]);
        push @order, $key;
      }
      return $params unless @order;
  
      foreach (@order) {
        last unless @$params;
        $_ = "-$_" unless /^-/;
        $return->{$_} = shift @$params;
      }
  
      return $return;
    }
  
    # Named parameters
    for (my $i = 0; $i < @$defaults; $i += 2) {
      my($key, $value) = ($defaults->[$i], $defaults->[$i + 1]);
      $return->{$key} = $value if defined $value;
    }
  
    for (my $i = 0; $i < @$params; $i += 2) {
      my($key, $value) = ($params->[$i], $params->[$i + 1]);
      $return->{$key} = $value;
    }
    return $return;
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
            ($runtime, $site) = ($_[0]->provider->runtime, $_[0]->provider->site);
    } else {
        ($runtime, $site) = ($agent->runtime, $agent->site);
    }
    return Conform::Core::i_isa_mergeall ($site->nodes, $runtime->iam, @_);
}

1;
