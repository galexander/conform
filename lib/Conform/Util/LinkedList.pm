package Conform::Util::LinkedList;
use strict;
use Mouse;
use Carp qw(croak);

=head1  NAME

Conform::Util::LinkedList

=head1  SYNOPSIS

    use Conform::Util::LinkedList;

    my $ll = Conform::Util::LinkedList->new();

=head1  DESCRIPTION

=cut

with 'Conform::Role::List';
with 'Conform::Role::Queue';

# private subs
sub _to_array;

=head1  ACCESSOR METHODS

=cut

=head2  list

=cut

has 'list' => (
    is  => 'rw',
    isa => 'ArrayRef',
    default => sub { [] },
);

=head1  OBJECT METHODS

=cut

=head2  size

=cut

sub size {
    my $self = CORE::shift;
    return scalar @{$self->list};
}

=head2  head

=cut

sub head {
    my $self = CORE::shift;
    my $list = $self->list;
    return $list->[0];
}

=head2  tail

=cut

sub tail {
    my $self = CORE::shift;
    my $list = $self->list;
    return $list->[-1];
}

sub push {
    my $self = CORE::shift;
    my $data = CORE::shift;
    my $list = $self->list;
    CORE::push @{$list}, $data;
}

sub unshift {
    my $self = CORE::shift;
    my $data = CORE::shift;
    my $list = $self->list;
    CORE::unshift @{$list}, $data;
}

sub pop {
    my $self = CORE::shift;
    my $list = $self->list;

    CORE::pop @{$list};
}

sub shift {
    my $self = CORE::shift;
    my $list = $self->list;

    CORE::shift @{$list};

}

=head2  append

=cut

sub append {
    my $self = CORE::shift;
    $self->push(@_);
}

=head2  prepend

=cut

sub prepend {
    my $self = CORE::shift;
    $self->unshift(@_);
}

=head2  add

=cut

sub add {
    my $self = CORE::shift;
    $self->append(@_);
}

=head2  add_all

=cut

sub add_all {
    my $self = CORE::shift;
    CORE::push @{$self->list}, _to_array @_;
}

=head2  add_list

=cut

sub add_list {
    my $self = CORE::shift;
    my @a = _to_array $_[0]->list;
    CORE::push @{$self->list}, _to_array $_[0]->list;
}

=head2  add_at

=cut

sub add_at {
    my $self = CORE::shift;
    my $idx  = CORE::shift;
    my $data = CORE::shift;

    $idx > $self->size
        and croak "index \$idx out of bounds for list @{[ $self->size ]}";

    splice @{$self->list}, $idx, 0, $data;
}

=head2  add_all_at

=cut

sub add_all_at {
    my $self = CORE::shift;
    my $idx  = CORE::shift;

    $idx > $self->size
        and croak "index \$idx out of bounds for list @{[ $self->size ]}";

    splice @{$self->list}, $idx, 0, _to_array @_;
}

=head2  add_list_at

=cut

sub add_list_at {
    my $self = CORE::shift;
    my $idx  = CORE::shift;

    $idx > $self->size
        and croak "index \$idx out of bounds for list @{[ $self->size ]}";

    splice @{$self->list}, $idx, 0, _to_array $_[0]->list;
}

=head2  enqueue

=cut

sub enqueue {
    my $self = CORE::shift;
    $self->prepend(@_);
}

=head2  remove

=cut

sub remove {
    my $self = CORE::shift;
    return CORE::shift @{$self->list};
}

=head2  remove_at

=cut

sub remove_at {
    my $self = CORE::shift;
    my $idx  = CORE::shift;

    $idx > $self->size
        and croak "index \$idx out of bounds for list @{[ $self->size ]}";

    splice @{$self->list}, $idx, 1;
}

=head2  remove_all_at

=cut

sub remove_all_at {
    my $self  = CORE::shift;
    my $idx   = CORE::shift;
    my $range = CORE::shift;

    $idx + $range > $self->size
        and croak "index \$idx out of bounds for list @{[ $self->size ]}";

    splice @{$self->list}, $idx, $range;

}

=head2  dequeue

=cut

sub dequeue {
    my $self = CORE::shift;
    $self->remove;
}

=head2  for_each

=cut

sub for_each {
    my $self = CORE::shift;
    my $cb   = CORE::shift;

    for my $node (@{$self->list}) {
        $cb->($node);
    }
}

=head2  find

=cut

sub find {
    my $self = CORE::shift;
    my $cb   = CORE::shift;

    for my $node (@{$self->list}) {
        return $node
            if $cb->($node);
    }
    return undef;
}

=head2  iterator

=cut

sub iterator {
    my $self = CORE::shift;
    return Conform::Util::LinkedListIterator->new(list => $self->list);
}

=head2  to_array

=cut

sub to_array {
    my $self = CORE::shift;
    return _to_array $self->list;
}

sub _to_array {
    return (ref $_[0]  and ref $_[0] eq 'ARRAY')
                ? @{$_[0]}
                :  @_ ;
}



1;

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

# vi: set ts=4 sw=4:
# vi: set expandtab:
