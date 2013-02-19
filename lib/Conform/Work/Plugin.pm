package Conform::Work::Plugin;
use Mouse;

extends 'Conform::Plugin';

use Conform::Core qw();
use Conform::Action;
use Storable qw(dclone);
use Conform::Debug qw(Trace Debug);
use Data::Dump qw(dump);
use Conform::Plugin;
use Conform::ExecutionContext;

sub import {
    my $package = shift;
    my $caller  = caller;
    my @args = splice(@_, 0, scalar @_);
    if (@args && @args %2 == 0) {
        my %args = @args;
        $caller = delete $args{package}
                    if exists $args{package};
    }

    no strict 'refs';

    *{"${caller}\::Action"}         = \&_action;
    *{"${caller}\::Args"}           = \&_args,
    *{"${caller}\::i_isa"}          = \&_i_isa;
    *{"${caller}\::i_isa_fetchall"} = \&_i_isa_fetchall;
    *{"${caller}\::i_isa_mergeall"} = \&_i_isa_mergeall;

    __PACKAGE__->SUPER::import (package => $caller);
}

has 'id'        => ( is => 'rw', isa => 'Str' );
has 'name'      => ( is => 'rw', isa => 'Str' );
has 'impl'      => ( is => 'rw', isa => 'CodeRef' );
has 'version'   => ( is => 'rw', isa => 'Str');

sub extract_directives {
    my $self       = shift;
    my @search     = @_;
    my @directives = ();
    for my $arg (grep { ref $_ eq 'HASH' } @search) {
        for my $key (keys %$arg) {
            if ($key =~ /^:(\S+)/) {
                push @directives, { $1 => $arg->{$key} };
            } else {
                if (ref $arg->{$key} eq 'HASH') {
                    Debug "Searching deep %s", dump($arg->{$key});
                    push @directives, $self->extract_directives ($arg->{$key});
                }
            }
        }
    }
    return @directives;
}


sub _args {
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

sub _agent {
    return Conform::ExecutionContext->current->agent;
}


sub _action {
    my $agent = _agent;
    my $action  = shift;
    Debug "Adding action $action\n";
    my $value = $agent->nodes->{$agent->iam}{$action};
    unless (defined $value) {
        push @{$agent->nodes->{$agent->iam}{$action}}, @_;
    } else {
        push @{$agent->nodes->{$agent->iam}{$action}}, [@_];
    }
}

sub _i_isa {
    my $agent = _agent;
    return Conform::Core::i_isa ($agent->nodes, $agent->iam, @_);
}

sub _i_isa_fetchall {
    my $agent = _agent;
    return Conform::Core::i_isa_fetchall ($agent->nodes, $agent->iam, @_);
}

sub _i_isa_mergeall {
    my $agent = _agent;
    return Conform::Core::i_isa_mergeall ($agent->nodes,
                                          $agent->iam,
                                          @_);
}

1;
