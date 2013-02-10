package Conform::Action;
use Mouse;
use Conform::Logger qw($log);
use Data::Dump qw(dump);
use attributes;

=head1  NAME

Conform::Action

=head1  SYNSOPSIS

use Conform::Action;

=head1  DESCRIPTION

=cut

=head1   METHODS

=head2   name

=cut

=head2   desc

=cut

has 'id' => (
    is => 'rw',
);

has 'name' => (
    is => 'rw',
    isa => 'Str',
);

has 'complete' => (
    is => 'rw',
    isa => 'Bool',
);

has 'dependencies' => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { [] },
);

has 'provider' => (
    is => 'rw',
);

has 'args' => (
    is => 'rw',
    required => 1,
);

has 'result' => (
    'is' => 'rw',
);

sub execute {
    my $self = shift;
    my $provider = $self->impl;
    my @result = $provider->($self->args, $self, @_);
    $self->result(\@result);
}



sub BUILD {
    my $self = shift;
    $self;
}

sub satisfies {
    my $self = shift;
    my $dependency = shift;
    my $checked = 0;
    if (exists $dependency->{name}) {
        $checked++; 
        if ($self->name ne $dependency->{name}) {
            return 0;
        }
    }
    if (exists $dependency->{id}) {
        $checked++;
        if (defined $self->id) {
            if ($self->id ne $dependency->{id}) {
                return 0;
            }
        }
    }

    return $checked;
}

has 'impl' => (
    is => 'rw',
);


=head1  SEE ALSO

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
