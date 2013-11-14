package Conform::Logger::Stderr;
use Moose;

extends 'Conform::Logger::Appender';

=head1  NAME

Conform::Logger::Stderr

=head1 SYNOPSIS

 use Conform::Logger;
 Conform::Logger->set('Stderr');

=cut

=head1 DESCRIPTION

=cut

sub log {
    my $self = shift;
    my $msg = shift;
    printf STDERR "%s", $msg->{content} ."\n";
}



1;

# vi: set ts=4 sw=4:
# vi: set expandtab:
