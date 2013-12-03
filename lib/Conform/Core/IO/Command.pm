=encoding utf8

=head1 NAME

Conform::Core::IO::Command - Common 'command' utility functions

=head1 SYNOPSIS

    use Conform::Core::IO::Command qw(command);

    $status  = command $command, @args, \%flags;

=head1 DESCRIPTION

The Conform::Core::IO::Command module provides functions for command execution.

=cut

package Conform::Core::IO::Command;

use strict;
use warnings;

use Carp;
use Data::Dumper;
use Digest::MD5 qw( md5_hex );
use Digest::SHA qw( sha1_hex );
use POSIX qw( tmpnam setsid strftime F_SETFD FD_CLOEXEC SIGTERM SIGKILL uname );
use Errno qw( ENOENT );
use IO::File;
use IO::Pipe;
use IO::Socket;
use IO::Select;

use Conform::Core qw(action timeout safe);
use Conform::Logger qw(debug warn);

use base qw( Exporter );
use vars qw(
  $VERSION %EXPORT_TAGS @EXPORT_OK
);
$VERSION     = $Conform::VERSION;
%EXPORT_TAGS = (
    all => [
        qw(
          command
          find_command
          )
    ],
    deprecated => [
    ],
);

Exporter::export_ok_tags( keys %EXPORT_TAGS );

my ( $do_deprecated, %deprecated );

sub import {

    __PACKAGE__->export_to_level( 1, @_ );
    my $package = shift;
    $do_deprecated++ if grep /^:deprecated$/, @_;

    if ( grep { m/^:conformhandlers$/ } @_ ) {

        Conform::Log::import(':conformhandlers');

    }

}

sub _deprecated {
    my $key = shift;
    return if $deprecated{$key};
    $do_deprecated ? carp @_ : croak @_;
    $deprecated{$key}++;
}

=over

=item B<command>

    $status = command $command, @args, \%flags;

If safe mode is not enabled, runs the specified command with the given arguments
and returns the child process's exit status. The command and list of arguments
are treated just as in C<system>: if no arguments are provided, then the command
is passed to the shell or internally word-splitted according to whether it
contains shell metacharacters.

An optional flags hashref may be supplied as the last argument. The following
flags are recognized:

=over

=item I<note>

Message to be logged prior to executing the command, regardless of whether safe
mode is enabled or not. (This is used as the message in B<action>.)

=item I<intro>

Message to be logged prior to executing the command.

=item I<success>

Message to be logged if the command's exit status was zero.

=item I<failure>

Message to be logged if the command failed. If omitted, a useful default is
used instead.

=item I<capture>

If this is a scalar, controls whether the standard output and standard
error streams from the child process should be captured. By default
these streams are captured, but providing a false value for this flag
will connect these streams to F</dev/null> instead. Command output
is not logged.

If this is a scalar reference, then the command output will be appended
to the scalar (in addition to being logged)

If this is an array reference, then the command output will be pushed
on to the array (in addition to being logged)

If this is a subrouting (code) reference, then the reference will be
called with the command output as the only argument.

=item I<timeout>, I<read_timeout>, I<wait_timeout>, I<kill_timeout>

Various timeouts used when running the command.

I<read_timeout> specifies the time to wait for data to be read from the process.
By default, there is no read timeout.

I<wait_timeout> specifies the time to wait for the process to exit after the
pipe from it has closed. By default, there is no wait timeout.

I<timeout> can be specified to set both I<read_timeout> and I<wait_timeout> at
once.

If the process does timeout, either during reading or waiting, then it is sent a
SIGTERM signal. I<kill_timeout> specifies how long to wait for the process to
exit after this timeout. If the process does not exit before this time it is
sent a SIGKILL signal. By default, the kill timeout is 10 seconds.

=item I<nosafe>

This option instructions to ignore the safe flag. This is useful when a command can
safely be run without anything changing. For example, if dmidecode was used to
examine part of the system.

=back

=cut

sub _lines_prefix {
    my $prefix = shift || '';
    my $lines = join '', @_;
    $lines =~ s/\n+\z//;    # zaps trailing endlines
    my @l = map { m/^\Q$prefix/ ? "$_\n" : "$prefix$_\n" }
      split /[\r\n]+/, $lines;

    return wantarray ? @l : join( '', @l );
}

{
    my $nl = 1;

    sub _debug_cmd;
    sub _debug_cmd {
        my $text = shift;
        unless ( defined $text ) {
            _debug_cmd "\n" unless $nl;
            return;
        }

        return unless length $text;

        debug _lines_prefix( 'CMD: ', $text );

        $nl = $text =~ m/\n\z/;
        return 1
    }
}



sub command {
    my $flags = {};
    $flags = pop @_ if @_ and ref $_[-1] eq 'HASH';

    my @command = @_;
    @command and defined $command[0]
      or croak 'Usage: Conform::Core::IO::Command::command($command, @args, \%flags)';

    my $command = join ' ', @command;

    $flags->{intro}   ||= '';
    $flags->{success} ||= '';
    $flags->{failure} ||= $flags->{failure} = "FAILED: '$command' failed";
    $flags->{capture} = 1 unless exists $flags->{capture};
    $flags->{timeout}      ||= undef;
    $flags->{read_timeout} ||= $flags->{timeout};
    $flags->{wait_timeout} ||= $flags->{timeout};
    $flags->{kill_timeout} = 10 unless exists $flags->{kill_timeout};

    local $Conform::Core::safe_mode = $Conform::Core::safe_mode;
    $Conform::Core::safe_mode = 0 if $flags->{nosafe};

    my $result = action(
        $flags->{note} => sub {
            debug $flags->{intro}  if $flags->{intro};

            my $pipe = IO::Pipe->new()
              or die "Could not create status pipe: $!\n";

            my $cmd   = IO::File->new();
            my $child = $cmd->open('-|');
            defined $child
              or die "Could not fork in command: $!\n";

            local $SIG{PIPE} = 'IGNORE'
                unless $child;

            unless ($child) {

                # detach from controlling tty
                setsid;
                open STDIN, '<', '/dev/null';
                open STDOUT, '>', '/dev/null' unless $flags->{capture};
                open STDERR, '>&STDOUT'; # in the future, open (STDERR, '>&', \*STDOUT)

                my $ok = $pipe->writer
                  and fcntl $pipe, F_SETFD, FD_CLOEXEC;

                local $^W;
                unless ( $ok and exec @command ) {
                    select $pipe;
                    $|++;
                    print 0 + $!;
                    POSIX::_exit(1);
                }
            }

            local $_;
            local $SIG{CHLD} = 'DEFAULT';

            $pipe->reader
              or die "Could not close write end of status pipe: $!\n";

            my $result = '';
            while (1) {
                local $_;
                my $read = $pipe->sysread( $_, 16 );
                defined $read
                  or die "Could not read from status pipe: $!\n";
                $read
                  or last;
                $result .= $_;
            }

            undef $pipe;

            if ( $result ne '' ) {
                $! = 0 + $result;
                die "Could not execute $command: $!\n";
            }

            my $timed_out = 1;
            my $out       = length $flags->{intro};

            my $s = IO::Select->new($cmd);
            my $capture;
            while ( my $line = $s->can_read( $flags->{read_timeout} ) ) {
                unless ( $cmd->sysread( $line, 1024 ) ) {
                    $timed_out = 0;
                    last;
                }

                $capture .= $line;
                _debug_cmd $line;    # puts the output on to the log

                $out += length $line;
            }

            _debug_cmd;              # puts an end line on to the log

            if (ref $flags->{capture}) {

                push @{$flags->{capture}}, ( map {"$_\n"} split(/\n/,$capture))
                    if ref $flags->{capture} eq 'ARRAY';

                ${$flags->{capture}} = $capture
                    if ref $flags->{capture} eq 'SCALAR';

                $flags->{capture}->($capture)
                    if ref $flags->{capture} eq 'CODE';

                # i cant think of any obvious ways to handle other
                # reference types

           }

           # Close our end of the pipe. Perl will wait to reap the process.
           # If the process isn't reaped within the wait timeout, try a SIGTERM.
           # If the process *still* isn't reaped within the kill timeout, send a
           # SIGKILL.
            {
                my ( $signame, $signal ) = ( TERM => SIGTERM );
                my $timeout = $flags->{wait_timeout};
                my $code = sub { $cmd->close };

                while ( timeout($timeout, $code) ) {
                    warn "[timeout -- sending SIG$signame]" ;
                    kill $signal, $child;
                    ( $signame, $signal ) = ( KILL => SIGKILL );
                    $timeout = $flags->{kill_timeout};
                    $code = sub { waitpid $child, 0 };
                }

            }

            if ( $? >> 8 ) {
                warn "$flags->{failure}  Exit code: " . ( $? >> 8 );
            }
            elsif ($?) {
                warn "$flags->{failure}  Signal: " . ( $? & 0x7f );
            }
            elsif ( $flags->{success} ) {
                debug $flags->{success};
            }

            return $?
        }
    );

    return $Conform::Core::safe_mode ? 0 : $result;
}

=back

=over 

=item B<find_command>

    $path = find_command $command;

Given an executable name find the full path.

=back

=cut

sub find_command {
    my $command = shift
        or return undef;

    for my $path (qw(/bin /sbin /usr/bin /usr/sbin /usr/local/bin)) {
        return "$path/$command"
            if -x "$path/$command";
    }
}



1;

=head1 SEE ALSO

=cut
