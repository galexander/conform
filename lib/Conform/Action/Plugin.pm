package Conform::Action::Plugin;
use Mouse;

extends 'Conform::Plugin';

use Conform::Core qw();
use Conform::Action;

sub import {
    my $package = shift;
    my $caller  = caller;

    no strict 'refs';
    *{"${caller}\::Action"} = \&Action;
    *{"${caller}\::i_isa"} = \&i_isa;
    *{"${caller}\::i_isa_fetchall"} = \&i_isa_fetchall;
    *{"${caller}\::i_isa_mergeall"} = \&i_isa_mergeall;

    __PACKAGE__->SUPER::import (package => $caller);
}

has 'id' => (is => 'rw', isa => 'Str');
has 'name' => ( is => 'rw', isa => 'Str');
has 'impl' => ( is => 'rw', isa => 'CodeRef' );
has 'version' => ( is => 'rw', isa => 'Str');

my $agent;
sub set_agent {
    my $package = shift;
    $agent = shift;
}


sub actions {
    my $self        = shift;
    my $agent       = shift;
    my $tag         = shift;
    my $value       = shift;

    __PACKAGE__->set_agent($agent);

    my $name    = $self->name();

    return () unless defined $value;

    my $Impl = sub {
        use Tie::Watch;
        no strict 'vars';
        #use vars qw/%m/;
        #local *m = $agent->site->nodes;

        my @changed = ();

        use Data::Dumper;
        my $_store = sub {
            my $self = shift;
            
            print Dumper(\@_);
            
        };
        
        my $watch = Tie::Watch->new(-variable => $agent->site->nodes->{$agent->runtime->iam}, -debug => 1, -store => $_store);
        my $result = $self->impl->(@_);
    };

    my $_scalar_action = sub {
        my $scalar = shift;
        return Conform::Action->new(
                'id' => undef,
                'args' => $scalar,
                'name' => $name,
                'provider' => $self,
                'impl' => sub {
                    # $Impl->($scalar,(shift @_), $agent)
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
    if (blessed $_[0]
         and $_[0]->isa('Conform::Action')) {
            ($runtime, $site) = ($_[0]->provider->runtime, $_[0]->provider->site);
            shift;
    } else {
        ($runtime, $site) = ($agent->runtime, $agent->site);
    }

    my $action  = shift;
    print "Adding action $action\n";
    push @{$site->nodes->{$runtime->iam}->{$action}}, @_;
}


sub i_isa {
    my ($runtime, $site);
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
    if (blessed $_[0]
         and $_[0]->isa('Conform::Action')) {
            ($runtime, $site) = ($_[0]->provider->runtime, $_[0]->provider->site);
    } else {
        ($runtime, $site) = ($agent->runtime, $agent->site);
    }
    return Conform::Core::i_isa_mergeall ($site->nodes, $runtime->iam, @_);
}

1;
