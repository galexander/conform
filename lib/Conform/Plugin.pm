package Conform::Plugin;

=head1  NAME

    Conform::Plugin

=head1  ABSTRACT

    Base class for Conform::Plugin's

=head1  SYNOPSIS

    use Conform::Plugin;

    sub method
        Type: {
    }

=head1  DESCRIPTION

Conform::Plugin is the base class that ALL plugins should extend.

=cut


use Mouse;
use Scalar::Util qw(refaddr weaken);
use Data::Dump qw(dump);
use Carp qw(croak);
use Conform;
use Conform::Debug qw(Debug);

our $VERSION = $Conform::VERSION;

has 'name' => (
    is => 'rw',
    isa => 'Str',
);

has 'version' => (
    is => 'rw',
    isa => 'Str',
);

sub id {
    my $self = shift;
    return sprintf "%s-%s",
                   $self->name,
                   $self->version;
}

has 'impl' => (
    is => 'rw',
    isa => 'Coderef',
);

sub type {
    my $self = shift;
    my $class = blessed $self;
    $class =~ /^Conform::(\S+)::Plugin/;
    my $type = $1;
    $type || croak "Unable to determine plugin type for $class";
    $type;
}

sub import {
    my $caller = caller;
    my @args = splice(@_, 1, $#_);
    if (@args && @args %2 == 0) {
        my %args = @args;
        $caller = delete $args{package}
                    if exists $args{package};
    }
    no strict 'refs';
    no warnings 'redefine';
    *{"${caller}\::MODIFY_CODE_ATTRIBUTES"}
            = \&MODIFY_CODE_ATTRIBUTES;
    *{"${caller}\::FETCH_CODE_ATTRIBUTES"}
            = \&FETCH_CODE_ATTRIBUTES;

    $_[0]->SUPER::import(@_);
}


has 'attr' => ( is => 'rw', isa => 'ArrayRef', default => sub { [] }  );

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


sub get_attr {
    my $self = shift;
    my $attr = shift;
    for (@{$self->attr}) {
        my ($name, $value) = (ref $_ eq 'HASH'
                                ? each %$_
                                : (ref $_ eq 'ARRAY'
                                     ? ($_->[0], $_->[1])
                                     : (!ref $_
                                            ? ($_ => 1)
                                            : ())));
                                
        if ($name eq $attr) {
            return $value;
        }
    }
}

sub get_attrs {
    my $self = shift;
    my $attr = shift;
    my @attr = ();
    for (@{$self->attr}) {
        my ($name, $value) = (ref $_ eq 'HASH'
                                ? each %$_
                                : (ref $_ eq 'ARRAY'
                                     ? ($_->[0], $_->[1])
                                     : (!ref $_
                                            ? ($_ => 1)
                                            : ())));

        if ($name eq $attr) {
            push @attr, $attr;
        }
    }
    return wantarray
            ? @attr
            :\@attr;
}

our %attrs;

sub MODIFY_CODE_ATTRIBUTES {
    my ($package, $subref, @attrs) = @_;
    $attrs{ $package } { refaddr $subref } = \@attrs;
    ();
}

sub FETCH_CODE_ATTRIBUTES {
    my ($package, $subref) = @_;
    my $attrs = $attrs{ $package } { refaddr $subref };
    return @{$attrs || [] };
}

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=head1  COPYRIGHT

Copyright 2012 (Gavin Alexander)

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module

=cut

1;
# vi: set ts=4 sw=4:
# vi: set expandtab:
