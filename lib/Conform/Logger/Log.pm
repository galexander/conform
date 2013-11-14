package Conform::Logger::Log;
use Moose;

=head1 NAME

Conform::Logger::Log - Keep track of log messages for a conform 'run'

=head1 SYNOPSIS

    use Conform::Logger::Log;
    my $log = Conform::Logger::Log->new();

    $log->append("message");
    my $messages = $log->get_messages();
    my $messages = $log->messages;
    print $$messages;

=cut

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

=head1  SEE ALSO

=over

=item   L<Log::Any>

=item   L<Log::Any::Adapter>

=back

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

1;

# vi: set ts=4 sw=4:
# vi: set expandtab:

