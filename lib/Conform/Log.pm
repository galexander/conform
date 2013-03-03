package Conform::Log;
use Mouse;

has 'messages' => (
    is => 'rw',
    isa => 'ScalarRef',
    default => sub { \(my $messages) }
);

sub get_messages {
    my $self = shift;
    my $messages = $self->messages;
    return $$messages;
}

sub append {
    my $self = shift;
    my $messages = $self->messages;
    $$messages .= (join "\n", @_) ."\n";
}

1;
