package Conform::Queue;
=head1 NAME

Conform::Queue

=head1 SYNOPSIS

    my $q = Conform::Queue->new();
    $q->enqueue;
    $q->dequeue;
    $q->size;
    $q->extract;
    $q->extract_single;
    $q->extract_multi;
    $q->remove;
    $q->traverse;

=head1 DESCRIPTION

Generic FIFO queue to hold L<Conform::Action>'s

=cut

use Mouse;
use Scalar::Util qw(refaddr);

=head1 METHODS

=over 4

=item * list

=back

=cut

has 'list' => (is =>'rw', isa => 'ArrayRef', default => sub {[]});

=over 4

=item * enqueue

=back

=cut


sub enqueue {
    my $self   = shift;
    my $object = shift;
    push @{$self->list}, $object;
}

=over 4

=item * dequeue

=back

=cut


sub dequeue {
    my $self = shift;

    my $list = $self->list;
    if (scalar @$list) {
        return shift @$list;
    }
}

=over 4

=item * size

=back

=cut


sub size {
    my $self = shift;
    return scalar @{$self->list};
}

=over 4

=item * extract

=back

=cut


sub extract {
    my $self  = shift;
    my $type  = shift;
    my $check = shift;

    if ($type eq 'single') {
        return $self->extract_single($check);
    } else {
        return $self->extract_multi($check);
    }
}

=over 4

=item * find

=back

=cut


sub find {
    my $self  = shift;
    my $type  = shift;
    my $check = shift;

    if ($type eq 'single') {
        return $self->find_single($check);
    } else {
        return $self->find_multi($check);
    }
}


=over 4

=item * remove_at

=back

=cut


sub remove_at {
    my $self  = shift;
    my $index = shift;

    my $list  = $self->list;
    return splice @$list, $index, 1;
}

=over 4

=item * remove

=back

=cut


sub remove {
    my $self = shift;
    my $elem = shift;
    my $list = $self->list;

    for (my $i = 0; $i < @$list; $i++) {
        if (refaddr $elem eq refaddr $list->[$i]) {
            return $self->remove_at($i);
        }
    }
}

=over 4

=item * extract_single

=back

=cut

sub extract_single {
    my $self  = shift;
    my $check = shift;

    my $list  = $self->list;
    for (my $i = 0; $i < scalar @$list; $i++) {
        if ($check->($list->[$i])) {
            return $self->remove_at($i);
        }
    }
}

=over 4

=item * extract_multi

=back

=cut

sub extract_multi {
    my $self  = shift;
    my $check = shift;

    my $list = $self->list;

    my @found = ();
    for (@$list) {
        if ($check->($_)) {
            push @found, $_;
        }
    }
    for (@found) {
        $self->remove($_);
    }
    return @found;
}

=over 4

=item * find_single

=back

=cut

sub find_single {
    my $self  = shift;
    my $check = shift;

    my $list  = $self->list;
    for (my $i = 0; $i < scalar @$list; $i++) {
        if ($check->($list->[$i])) {
            return $list->[$i];
        }
    }
}

=over 4

=item * find_multi

=back

=cut

sub find_multi {
    my $self  = shift;
    my $check = shift;

    my $list = $self->list;

    my @found = ();
    for (@$list) {
        if ($check->($_)) {
            push @found, $_;
        }
    }
    return @found;
}

=head1  AUTHOR

Gavin Alexander <gavin.alexander@gmail.com>

=cut

1;
