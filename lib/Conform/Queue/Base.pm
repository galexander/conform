#!/bin/false
package Conform::Queue::Base;

use strict;
use warnings;

# ABSTRACT: Conform Queue base

# FIXME: this might be better as a linked list, so that elements can be easily skipped?

our $VERSION = '0.1';    # VERSION

use Carp;

sub new {
    my ( $class, $elems ) = @_;

    $class = ref $class if ref $class;
    my $self = bless( { list => [] }, $class );

    if ( defined $elems && ref($elems) eq 'ARRAY' ) {
        @{ $self->{list} } = @{$elems};
    }

    return $self;
}

sub add {
    my ( $self, @args ) = @_;
    push @{ $self->{list} }, @args;
    return;
}

sub remove_all {
    my $self = shift;
    return ( $self->remove( $self->size ) );
}

sub remove {
    my $self = shift;
    my $num = shift || 1;

    return shift @{ $self->{list} } unless wantarray;

    croak 'Paramater must be a positive number' unless 0 < $num;

    my @removed = ();

    while ($num) {
        my $elem = shift @{ $self->{list} };
        last unless defined $elem;
        push @removed, $elem;
        $num--;
    }

    return @removed;
}

sub size {
    return scalar( @{ shift->{list} } );
}

sub empty {
    return shift->size == 0;
}

sub clear {
    shift->{list} = [];
    return;
}

sub copy_elem {
    my @elems = @{ shift->{list} };
    return @elems;
}

sub peek {
    my $self = shift;
    return $self->{list}->[0];
}

1;

__END__

=pod

=encoding utf-8

=head1 NAME

Conform::Queue::Base - Queue base functions, should be subclassed

=head1 VERSION

0.1

=head1 SYNOPSIS

    use Conform::Queue::Base;

    # construction
    my $queue = Queue::Base->new;
    # or
    my $queue = Queue::Base->new(\@elements);

    # add a new element to the queue
    $queue->add($element);

    # remove the next element from the queue
    if (! $queue->empty) {
        my $element = $queue->remove;
    }

    # or
    $element = $queue->remove;
    if (defined $element) {
        # do some processing here
    }

    # add/remove more than just one element
    $queue->add($elem1, $elem2 ...)
    # and
    @elements = $queue->remove(5);

=head1 DESCRIPTION

The Queue::Base is a simple implementation for queue structures using an
OO interface. Provides basic functionality: nothing less - nothing more.

=head1 METHODS

=head2 new [ELEMENTS]

Creates a new empty queue.

ELEMENTS is an array reference with elements the queue to be initialized with.

=head2 add [LIST_OF_ELEMENTS]

Adds the LIST OF ELEMENTS to the end of the queue.

=head2 remove [NUMBER_OF_ELEMENTS]

In scalar context it returns the first element from the queue.

In array context it attempts to return NUMBER_OF_ELEMENTS requested;
when NUMBER_OF_ELEMENTS is not given, it defaults to 1.

=head2 remove_all

Returns an array with all the elements in the queue, and clears the queue.

=head2 size

Returns the size of the queue.

=head2 empty

Returns whether the queue is empty, which means its size is 0.

=head2 clear

Removes all elements from the queue.

=head2 copy_elem

Returns a copy (shallow) of the underlying array with the queue elements.

=head2 peek

Returns the value of the first element of the queue, wihtout removing it.

=head1 CAVEATS

The module works only with scalar values. If you want to use more complex
structures (and there's a big change you want that) please use references,
which in perl5 are basically scalars.

=for :stopwords cpan testmatrix url annocpan anno bugtracker rt cpants kwalitee diff irc mailto metadata placeholders

=head1 AUTHOR

Dean Hamstead <dean@fragfest.com.au>

(based on Queue::Base by Alexei Znamensky <russoz@cpan.org>)

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Farkas Arpad, Alexei Znamensky.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut



