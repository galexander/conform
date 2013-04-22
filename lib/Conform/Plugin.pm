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
use Scalar::Util qw(blessed reftype refaddr weaken);
use Data::Dump qw(dump);
use Carp qw(croak);
use Conform;
use Conform::Debug qw(Debug);

our $VERSION = $Conform::VERSION;

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

=head1 METHODS

=head2 new - abstract constructor

    $plugin = new Conform::Foo::Plugin
                    name => name,
                    version => version,
                    impl => sub { .. };
=cut

sub BUILD {
    my $self = shift;
    die "@{[__PACKAGE__]} is an abstract class"
        if blessed $self eq __PACKAGE__;
    $self;
}


=head2 name

    $name = $plugin->name;

=cut

has 'name' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

=head2 version
    
    $version = $plugin->version;

=cut

has 'version' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

=head2 id

    $id = $plugin->id;

=cut

sub id {
    my $self = shift;
    return sprintf "%s-%s",
                   $self->name,
                   $self->version;
}

=head2 impl

    $impl = $plugin->impl;
    $impl->();

=cut

has 'impl' => (
    is => 'ro',
    isa => 'CodeRef',
    required => 1,
);

=head2 type
    
    $type = $plugin->type;

=cut

sub type {
    my $self = shift;
    my $class = blessed $self;
    $class =~ /Conform::(\S+)::Plugin/;
    my $type = $1;
    $type || croak "Unable to determine plugin type for $class";
    $type;
}

=head2 attr

    $attr = $plugin->attr;
    for (@$attr) {
        ...
    }

=cut

has 'attr' => (
    is => 'ro',
    isa => 'ArrayRef',
    default => sub { [] }
);

=head2 get_attr
    
    $value = $plugin->get_attr($attr)

=cut

sub _attr_iterate {
    my $attr = shift;
    my $sub  = shift;
    for (@{$attr}) {
        if (ref $_ eq 'HASH') {
            for my $key (keys %$_) {
                unless ($sub->($key, $_->{$key})) {
                    return;
                }
            }
        }
        elsif (ref $_ eq 'ARRAY') {
            for my $elem (@{$_}) {
                my ($key, $value) = split /=/, $elem;
                $value = 1 unless defined $value;
                unless ($sub->($key, $value)) {
                    return;
                }
            }
        }
        elsif(!ref $_) {
            my ($key, $value) = split /=/, $_;
            $value = 1 unless defined $value;
            unless ($sub->($key, $value)) {
                return;
            }
        }
    }
}

sub get_attr {
    my $self = shift;
    my $attr = shift;
    my $found;
    _attr_iterate $self->attr, sub {
        my ($key, $value) = @_;
        if ($key eq $attr) {
            $found = $value;
            return 0;
        }
        return 1;
    };

    return $found;
}



=head2 get_attrs

    $attrs = $plugin->get_attrs($attr);
    @attrs = $plugin->get_attrs($attr);
    for (@$attr) {
        ...
    }
    for (@attr) {
        ...
    }

=cut

sub get_attrs {
    my $self = shift;
    my $attr = shift;
    my @attr = ();
    _attr_iterate $self->attr, sub {
        my ($key, $value) = @_;
        if ($key eq $attr) {
            push @attr, $value;
        }
        return 1;
    };
    return wantarray
            ? @attr
            :\@attr;
}

our %package_attrs;

sub MODIFY_CODE_ATTRIBUTES {
    my ($package, $subref, @attrs) = @_;
    $package_attrs{ $package } { refaddr $subref } = \@attrs;
    ();
}

sub FETCH_CODE_ATTRIBUTES {
    my ($package, $subref) = @_;
    my $attrs = $package_attrs{ $package } { refaddr $subref };
    return @{$attrs || [] };
}

=head1 SEE ALSO

L<Conform::Work::Plugin>,
L<Conform::Action::Plugin>,
L<Conform::Task::Plugin>,
L<Conform::Data::Plugin>

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
