package Conform::Logger::File;
use Moose;

extends 'Conform::Logger::Appender';
use Carp qw(croak);


has 'file' => (
    is => 'rw',
    isa => 'Str',
);

sub log {
    my $self = shift;
    my $msg  = shift;
    my $file = $self->file;
    open my $fh, '>>', $file
           or die "open $file $!";
    print $fh $msg->{content} ."\n";
}

1;
