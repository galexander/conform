package Conform::Runtime::Server;
use strict;
use Mouse;
use Net::Domain qw(hostname hostfqdn hostdomain domainname);

=head1  NAME

Conform::Runtime::Server

=head1  SYNSOPSIS

use Conform::Runtime::Server;

=head1  DESCRIPTION

=cut

extends 'Conform::Runtime';

use parent 'Conform::Runtime';


sub BUILD {
    my $self = shift;
    $self->name($self->hostname)
        unless $self->name;
    $self;
}


sub File_install : Task {

}

=head1  SEE ALSO

L<Conform::Runtime>

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

1;

# vi: set ts=4 sw=4:
# vi: set expandtab:
