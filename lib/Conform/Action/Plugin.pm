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
has 'impl'      => ( is => 'rw', isa => 'CodeRef' );
has 'version'   => ( is => 'rw', isa => 'Str');
has 'arg_spec'  => ( is => 'rw');
has 'agent'     => ( is => 'rw');

sub _get_positional_args {
    my ($name, $args, $spec) = @_;
    Debug "_get_positional_args %s %s",
          dump($args),
          dump($spec);

    $args = dclone $args;

    my %formatted = ();
    for my $check (@$spec) {
        my $arg = shift @$args;
        if ($check->{required}) {
            die "$name:missing required $check->{arg}"
                unless defined $arg;
        }
        if ($check->{type}) {
            die "$name:$check->{arg} invalid type @{[ ref $arg ]}"
                if defined $arg and
                       ref $arg ne $check->{type};

            $arg = $check->{type} eq 'HASH'
                        ? {}
                        : [];
        }
        $formatted{_id} = $arg
            unless exists $formatted{_id};
        $formatted{$check->{arg}} = $arg;
    }
    return \%formatted;
}

sub _get_named_args {
    my ($name, $args, $spec) = @_;
    Debug "_get_named_args %s %s",
          dump($args),
          dump($spec);

    $args = dclone $args;

    my %formatted = ();
    for my $check (@$spec) {
        my $arg = $args->{$check->{arg}};
        if ($check->{required}) {
            die "$name:missing  require $check->{arg}"
                unless defined $arg;
        }
        if ($check->{type}) {
            die "$name:$check->{arg} invalid type @{[ ref $arg ]}"
                if defined $arg && 
                       ref $arg ne $check->{type};

            $arg = $check->{type} eq 'HASH'
                        ? {}
                        : [];
        }
        $formatted{_id} = $arg
            unless exists $formatted{_id};
        $formatted{$check->{arg}} = $arg;
    }
    return \%formatted;

}

sub _extract_directives;
sub _extract_directives {
    my @search     = @_;
    my @directives = ();
    for my $arg (grep { ref $_ eq 'HASH' } @search) {
        Debug "Arg = %s", dump($arg);
        for my $key (keys %$arg) {
            Debug "Key = %s\n", $key;
            if ($key =~ /^:(\S+)/) {
                Debug "Matching...\n";
                push @directives, { $1 => $arg->{$key} };
                Debug "%s", dump(\@directives);
            } else {
                if (ref $arg->{$key} eq 'HASH') {
                    Debug "Searching deep %s", dump($arg->{$key});
                    push @directives, _extract_directives ($arg->{$key});
                }
            }
        }
    }
    return @directives;
}

sub actions {
    my ($self, $agent, $tag, $args) = @_;

    Trace;

    my $name = $self->name;

    my $action_impl = sub {
        return $self->impl->(@_);
    };

    #my @directives = _extract_directives $args;

    #Debug "directives for %s %s = %s",
    #        $tag, dump($args), dump(\@directives);

    my $arg_spec = $self->arg_spec;

    if (defined $arg_spec) {
        my $spec = dclone $arg_spec;
        my $id   = $spec->[0]->{arg};
        my @actions;
        if (ref $args eq 'ARRAY') {
            for my $_args (@$args) {
                my $formatted;
                if (ref $_args eq 'ARRAY') {
                    $formatted = _get_positional_args $tag, $_args, $spec;
                }
                elsif (ref $_args eq 'HASH') {
                    $formatted = _get_named_args $tag, $_args, $spec;
                }
                elsif(!ref $_args) {
                    $formatted = _get_positional_args $tag, [$_args], $spec;
                }
                if ($formatted) {
                    push @actions,
                        Conform::Action->new('id'         => $formatted->{_id},
                                             'args'       => $formatted,
                                             'name'       => $name,
                                             'provider'   => $self,
                                             'impl'       => $action_impl,
                                             'directives' => [_extract_directives $_args]);
                }
            }
        }
        elsif (ref $args eq 'HASH') {
            for my $_arg (keys %$args) {
                my $_args = $args->{$_arg};
                my $formatted;
                if (ref $_args eq 'ARRAY') {
                    $formatted = _get_positional_args $tag, [$_arg, @$_args], $spec;
                }
                elsif (ref $_args eq 'HASH') {
                    $formatted = _get_named_args $tag, { $id => $_arg, %$_args }, $spec;
                }
                elsif(!ref $_args) {
                    $formatted = _get_positional_args $tag, [$_arg, $_args], $spec;
                }
                if ($formatted) {
                    push @actions,
                        Conform::Action->new('id'         => $formatted->{_id},
                                             'args'       => $formatted,
                                             'name'       => $name,
                                             'provider'   => $self,
                                             'impl'       => $action_impl,
                                             'directives' => [_extract_directives $_args]);
                }

            }
        }
        elsif (!ref $args) {
            my $formatted = _get_positional_args $tag, [$args], $spec;
            push @actions,
                    Conform::Action->new('id'         => $formatted->{_id},
                                         'args'       => $formatted,
                                         'name'       => $name,
                                         'provider'   => $self,
                                         'impl'       => $action_impl,
                                         'directives' => []);

        }
        return @actions;
    }

    
    return () unless defined $args;

    if (ref $args eq 'ARRAY') {
        my @actions = ();
        for my $value (@$args) {
            push @actions,
                 Conform::Action->new('args'       => $value,
                                      'name'       => $name,
                                      'provider'   => $self,
                                      'impl'       => $action_impl,   
                                      'directives' => [_extract_directives $value]);
        }
        return @actions;
    }

    if (ref $args eq 'HASH') {
        my @actions = ();
        for my $key (keys %$args) {
            push @actions,
                 Conform::Action->new('args'       => {$key => $args->{$key}},
                                      'name'       => $name,
                                      'provider'   => $self,
                                      'impl'       => $action_impl,
                                      'directives' => [_extract_directives $args->{$key}]);
        }
        return @actions;
    }

    return (Conform::Action->new('args'       => $args,
                                 'name'       => $name,
                                 'provider'   => $self,
                                 'impl'       => $action_impl,
                                 'directives' => []));

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
  
    # Named args
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
