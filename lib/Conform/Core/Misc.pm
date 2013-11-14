#!/bin/false

=encoding utf8

=head1 NAME

Conform::Core::Misc - Conform misc utility functions

=head1 SYNOPSIS

    use Conform::Core::Misc qw(:all);

    $host     = ip2host($ip);
    $updated  = x509_cert $cert, $key, \%attr;

    inetd_service @args;

=head1 DESCRIPTION

The Conform::Core::Misc module contains a collection of misc functions 
that should really be moved somewhere else. 

=cut

package Conform::Core::Misc;

use strict;
use warnings;

use Carp;
use Data::Dumper;
use Digest::MD5 qw( md5_hex );
use Digest::SHA qw( sha1_hex );
use Errno qw( ENOENT );
use POSIX qw( tmpnam setsid strftime F_SETFD FD_CLOEXEC SIGTERM SIGKILL uname );
use Time::Local;
use IO::Dir;
use IO::File;
use IO::Pipe;
use IO::Socket;
use IO::Select;
use Sys::Hostname;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Date qw( time2str );
use Text::Template;
use Conforn::Logger qw($log debug trace warn notice fatal);
use Conform::Core::IO::Command qw(command);
use Conform::Core::IO::File qw(dir_install safe_write_file safe);

use base qw( Exporter );
use vars qw(
  $VERSION %EXPORT_TAGS @EXPORT_OK
);
$VERSION     = (qw$Revision: 1.127 $)[1];
%EXPORT_TAGS = (
    all => [
        qw(
          ip2host
          x509_cert
          )
    ],
);

Exporter::export_ok_tags( keys %EXPORT_TAGS );

=head1 FUNCTIONS

=over

=item B<ip2host>

  $hostname = ip2host('192.0.2.100');

Tries to find the hostname for an IP address (ie reverse look up)

=cut

sub ip2host {
    my $ip = shift or return;
    use Socket;
    return $ip unless $ip =~ m/^\d+\.\d+\.\d+\.\d+$/;

    return gethostbyaddr( inet_aton($ip), AF_INET ) || undef;
}


=item B<x509_cert>

    $updated = x509_cert $cert, $key, \%attr;

If safe mode is not enabled, generate a X.509 certificate and key. If the
certificate or key changed, a true value is returned.

The optional attribute hashref can be used to override attributes of
the certificate:

=over

=item I<C>

Country (required)

=item I<ST>

State (required)

=item I<L>

Location (required)

=item I<O>

Organization (required)

=item I<OU>

Organizational unit (required)

=item I<CN>

Common name (default: the hostname)

=item I<validity>

Certificate validity in days (default: 365)

=back

=cut

sub x509_cert {
    my ( $cert, $key, $attr ) = @_;
    $attr ||= {};

    defined $cert and defined $key and ref $attr eq 'HASH'
      or croak 'Usage: Conform::Core::IO::File::x509_cert($cert, $key, \%attr)';

    for (qw(C ST L O OU)) {
        exists $attr->{$_}
            and $attr->{$_}
                or die "x509_cert missing required paramater: $_";
    }

    $attr->{CN}       ||= hostname;
    $attr->{validity} ||= 365;

    if ( -f $key and -f $cert ) {

        # If the certificate is NOT expiring soon, we check the certificate's
        # subject and serial
        if ( -M _ < $attr->{validity} - 21 ) {
            my $pipe = IO::File->new(
                "/usr/bin/openssl x509 -in $cert -serial -subject -noout |")
              or die "Could not pipe from openssl: $!\n";
            my %cur = map m{^(\w+)=\s*/?(.*)}, <$pipe>;
            $pipe->close
              or die $!
              ? "Could not close pipe from openssl: $!\n"
              : "Exit status from openssl: $?\n";

            my $new = join '/', map { "$_=$attr->{$_}" }
              grep { length $attr->{$_} } qw/C ST L O OU CN/;

            # Certificate is OK if subject matches and serial is not zero
            return 0 if $cur{subject} eq $new and $cur{serial} ne '00';
        }
    }

    for ( $cert, $key ) {
        ( my $path = $_ ) =~ s,/[^/]+$,,;
        dir_check $path;
    }

    safe_write_file "$cert.config", <<EOT;
[req]
prompt=no
distinguished_name=req_dn

[req_dn]
C=$attr->{C}
ST=$attr->{ST}
L=$attr->{L}
O=$attr->{O}
OU=$attr->{OU}
CN=$attr->{CN}
EOT

    command '/usr/bin/openssl', 'req', '-new', '-x509', '-nodes',
      -keyout     => "$key.temp",
      -out        => "$cert.temp",
      -days       => $attr->{validity},
      -set_serial => time(),
      -config     => "$cert.config",
      { note => 'Generating X.509 certificate and key', };

    action 'Installing certificate and key' => sub {
        file_install $cert, "$cert.temp";
        file_install $key,  "$key.temp";
    };

    safe sub {
        for my $q ( "$cert.config", "$cert.temp", "$key.temp" ) {
            unlink $q
              or die "Could not unlink $cert.config: $!\n";
        }
    };

    return 1
}

=back

=cut

1;

=head1 SEE ALSO

L<conform>

=cut
