package Conform::Action::Plugin;
use Mouse;

extends 'Conform::Work::Plugin';

use Storable qw(dclone);
use Conform::Debug qw(Trace Debug);
use Data::Dump qw(dump);

use Conform::Core qw();
use Conform::Action;

sub import {
    my $package = shift;
    my $caller  = caller;

    __PACKAGE__->SUPER::import (package => $caller);
}

has 'arg_spec'  => ( is => 'rw');

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

            $arg ||= $check->{type} eq 'HASH'
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
        Debug "Arg = @{[dump $arg]}";
        if ($check->{required}) {
            die "$name:missing required arg '$check->{arg}'"
                unless defined $arg;
        }
        if ($check->{type}) {
            die "$name:$check->{arg} invalid type @{[ ref $arg ]}"
                if defined $arg && 
                       ref $arg ne $check->{type};

            $arg ||= $check->{type} eq 'HASH'
                        ? {}
                        : [];
        }
        $formatted{_id} = $arg
            unless exists $formatted{_id};
        $formatted{$check->{arg}} = $arg;
    }
    Debug "formatted = @{[ dump \%formatted ]}";
    return \%formatted;

}

sub _extract_directives;
sub _extract_directives {
    my @search     = @_;
    my @directives = ();
    for my $arg (grep { ref $_ eq 'HASH' } @search) {
        for my $key (keys %$arg) {
            if ($key =~ /^:(\S+)/) {
                push @directives, { $1 => $arg->{$key} };
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

sub factory {
    my ($self, $agent, $tag, $args) = @_;

    Trace;

    my $name = $self->name;

    my $action_impl = sub {
        return $self->impl->(@_);
    };

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

1;
