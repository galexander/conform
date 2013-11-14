package Conform::Runtime::Server::Posix;
use strict;
use Moose;
use Net::Domain ();
use POSIX ();
use Conform::Plugin;

=head1  NAME

Conform::Runtime::Server

=head1  SYNSOPSIS

use Conform::Runtime::Server::Posix;

=head1  DESCRIPTION

=cut

extends 'Conform::Runtime::Server';

=head1  METHODS

=head2  os

=cut

sub os { $^O }

sub uname {
    my @uname = POSIX::uname;

    my %uname = ();
    for (qw(sysname nodename release version machine)) {
        $uname{$_} = shift @uname;
    }
    return \%uname;
}

sub posix_sysname  { return uname()->{sysname};  }

sub posix_nodename { return uname()->{nodename}; }

sub posix_release  { return uname()->{release};  }

sub posix_version  { return uname()->{version};  }

sub posix_machine  { return uname()->{machine};  }

sub arch { posix_machine; } 

sub hostname    { Net::Domain::hostname }

sub hostfqdn    { Net::Domain::hostfqdn }

sub hostdomain  { Net::Domain::hostdomain }

sub domainname  { Net::Domain::domainname }


=head1  SEE ALSO

L<Conform::Runtime>

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

1;

# vi: set ts=4 sw=4:
# vi: set expandtab:
