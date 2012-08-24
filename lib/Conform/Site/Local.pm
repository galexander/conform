package Conform::Site::Local;
use strict;
use Mouse;
use Carp qw(croak);

extends 'Conform::Site';
with    'Conform::Site::API';

use IO::Dir;
use IO::File;

use Conform::Logger qw($log);

=head1  NAME

Conform::Site::Local

=head1  SYNSOPSIS

use Conform::Site::Local;

=head1  DESCRIPTION


=cut

=head1  CONSTRUCTOR

=head2  new

=cut

sub new {
    my $class = shift;
    $log->debugf("%s->new", $class);
    my $self = $class->SUPER::new(@_);
    
    $self->init();

    return $self;
}


sub dir_list {
    my $self = shift;
    my $path = shift;

    $log->debugf("%s->dir_list(%s)", ref $self, $path);

    my $dir = IO::Dir->new($path)
                or die "$!";

    my @files;

    for my $file ($dir->read) {
        push @files, $file;
    }

    return wantarray
            ?  @files
            :\ @files;
}

sub file_open {
    my $self = shift;
    my $file = shift;

    $log->debugf("%s->file_open(%s)", ref $self, $file);

    my $fh = IO::File->new($file)
                or die "$!";

    return $fh;
}

sub file_close {
    my $self = shift;
    my $fh   = shift;
    $log->debugf("%s->file_close(%s)", ref $self, $fh);

    $fh->close
        if $fh and ref $fh and $fh->can('close');
}

sub file_read {
    my $self = shift;
    my $file = shift;

    $log->debugf("%s->file_read(%s)", ref $self, $file);

    my $fh = $self->file_open($file);
    
    return wantarray
            ? (<$fh>)
            : do { local $/; <$fh> };
}

=head1  SEE ALSO

L<Conform::Site>

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

1;

# vi: set ts=4 sw=4:
# vi: set expandtab:
