package Conform::ExecutionContext;
use Moose;

our @stack = ();

has 'agent' => (
    is => 'rw',
    isa => 'Conform::Agent',
    required => 1,
);

has 'work' => (
    is => 'rw',
    isa => 'Conform::Work',
    required => 1,
);

sub push {
    my $self = shift;
    push @stack, $_[0];
}

sub pop {
    my $self = shift;
    pop @stack;
}

sub current {
    my $self = shift;
    return $stack[-1];
}


1;

