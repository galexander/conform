package Conform::Logger::Stdout;
use Moose;

extends 'Conform::Logger::Appender';

=head1  NAME

Conform::Logger::Stdout

=head1 SYNOPSIS

 use Conform::Logger;
 Conform::Logger->set('Stdout');

=cut

=head1 DESCRIPTION

=cut

sub log {
    my $self = shift;
    my $msg = shift;
    print $msg->{content} . "\n";
}

1;

# vi: set ts=4 sw=4:
# vi: set expandtab:
