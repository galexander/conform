#!/usr/bin/perl
# $Id: Utils.pm,v 1.127 2012/11/23 04:38:22 rodrigo Exp $

=encoding utf8

=head1 NAME

Conform::Core::IO::HTTP - Optus Internet Engineering common utility functions

=head1 SYNOPSIS

    use Conform::Core::IO::HTTP qw(:all :deprecated :oiehandlers);

    $Conform::Core::IO::HTTP::debug          = $debug;
    $Conform::Core::IO::HTTP::safe_mode      = $safe_mode;
    $Conform::Core::IO::HTTP::safe_write_msg = $message;
    $log_messages = $Conform::Core::IO::HTTP::log_messages;

    debug @messages;
    note  @messages;
    warn  @messages;
    die   @messages;

    $result  = action $message => \&code, @args;
    $result  = safe   \&code, @args;

    $status  = command $command, @args, \%flags;

    $content = slurp_file $filename;
    @lines   = slurp_file $filename;

    $content = slurp_http $uri, \%flags;
    @lines   = slurp_http $uri, \%flags;

    safe_write      $filename, @lines, \%flags;
    safe_write      $filename, \*FH,   \%flags;
    safe_write_file $filename, @lines, \%flags;
    safe_write_file $filename, \*FH,   \%flags;

    $updated  = set_attr $filename, \%flags;
    %attr     = get_attr $filename;
    %attr     = get_attr \*FH;

    $updated  = text_install $filename, $text,   $cmd, \%flags;
    $updated  = file_install $filename, $source, $cmd, \%flags, @expr;
    $updated  = http_install $filename, $uri,    $cmd, \%flags, @expr;

    $updated  = file_append $filename, $line, $regex, $cmd, $create;
    $updated  = file_modify $filename, $cmd, @expr;
    $unlinked = file_unlink $filename, $cmd;

    $updated  = file_comment_spec   $filename, $comment, $cmd, @regex;
    $updated  = file_comment        $filename,           $cmd, @regex;
    $updated  = file_uncomment_spec $filename, $comment, $cmd, @regex;
    $updated  = file_uncomment      $filename,           $cmd, @regex;

    $updated  = template_install $filename, $template, \%data, $cmd, \%flags;
    $updated  = template_file_install $filename, $template_file, \%data, $cmd, \%flags;
    $updated  = template_text_install $filename, $template_text, \%data, $cmd, \%flags;

    $filenames = dir_list $uri, \%flags;
    @filenames = dir_list $uri, \%flags;
    $filenames = dir_list_http $uri, \%flags;
    @filenames = dir_list_http $uri, \%flags;

    $updated  = dir_check   $dirname, $cmd, \%flags;
    $updated  = dir_install $dirname, $source, $cmd, \%flags;
    $updated  = dir_install_http $dirname, $source, $cmd, \%flags;

    $updated  = symlink_check $target, $symlink, \%flags;

    $tty  = this_tty;
    $host = ip2host($ip);

    $updated  = x509_cert $cert, $key, \%attr;

    # Deprecated functions (only imported with :deprecated)
    warning @messages;
    scream  @messages;

    $updated = file_install_http $uri, $filename;

    inetd_service @args;

    # Warning and Die handlers are customized if
    # :oiehandlers

=head1 DESCRIPTION

The Conform::Core::IO::HTTP module contains a collection of useful functions for use in OIE
scripts (primarily C<conform>).

=cut

package Conform::Core::IO::HTTP;

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

use Conform::Log qw( debug note lines_prefix $debug $log_messages );

use base qw( Exporter );
use vars qw(
  $VERSION %EXPORT_TAGS @EXPORT_OK
  $debug $safe_mode $safe_write_msg $log_messages $warnings
);
$VERSION     = (qw$Revision: 1.127 $)[1];
%EXPORT_TAGS = (
    all => [
        qw(
          debug note
          action safe
          command
          slurp_file slurp_http
          safe_write safe_write_file
          set_attr get_attr
          text_install file_install http_install
          file_audit file_append file_modify file_unlink
          file_comment_spec file_comment file_uncomment_spec file_uncomment
          template_install template_file_install template_text_install
          dir_check dir_install dir_install_http
          dir_list dir_list_http
          symlink_check
          this_tty ip2host
          x509_cert
          )
    ],
    deprecated => [
        qw(
          warning scream
          file_install_http
          inetd_service
          )
    ],
);

@EXPORT_OK = qw( $safe_mode );

Exporter::export_ok_tags( keys %EXPORT_TAGS );

use constant HTTP_CACHE => '/var/cache/conform';
use constant HTTP_TIMEOUT => 10;

# The first constant is from http://www.netadmintools.com/html/2ioctl_list.man.html
# Hard coding these removes the need to depend on h2ph

use constant EXT2_IOC_GETFLAGS => ( (+(uname())[4] eq 'x86_64') ? 0x80086601 : 0x80046601);
use constant EXT2_IOC_SETFLAGS => ( (+(uname())[4] eq 'x86_64') ? 0x40086602 : 0x40046602);
use constant EXT2_IMMUTABLE_FL => 16;
use constant EXT2_APPEND_FL    => 32;

# color values

my $RESET  = "\e[0m";
my $BOLD   = "\e[1m";
my $RED    = "\e[31m";
my $YELLOW = "\e[33m";
my $CYAN   = "\e[36m";

# commands we use

my $ci = '/usr/bin/ci';
die "Couldnt find $ci, this is absolutely required" unless -x $ci;

my $intest = $ENV{'HARNESS_VERSION'} || $ENV{'HARNESS_ACTIVE'};

my ( $do_deprecated, %deprecated );

sub import {

    __PACKAGE__->export_to_level( 1, @_ );
    my $package = shift;
    $do_deprecated++ if grep /^:deprecated$/, @_;

    if ( grep { m/^:oiehandlers$/ } @_ ) {

        Conform::Log::import(':oiehandlers');

    }

}

sub _deprecated {
    my $key = shift;
    return if $deprecated{$key};
    $do_deprecated ? carp @_ : croak @_;
    $deprecated{$key}++;
}

=head1 VARIABLES

=over

=item B<$Conform::Core::IO::HTTP::safe_mode>

    $Conform::Core::IO::HTTP::safe_mode = $safe_mode;

When set, potentionally dangerous actions are not performed. By default, safe
mode is I<not> enabled.

=item B<$Conform::Core::IO::HTTP::safe_write_msg>

    $Conform::Core::IO::HTTP::safe_write_msg = $message;

The log message used when checking files into RCS.

=back

=cut

$safe_mode      = 0;
$safe_write_msg = "Changed by $0";

=head1 FUNCTIONS

=over

=item B<action>

    $result = action $message => \&code, @args;

Logs the supplied message (using B<note>) if it is not empty, then, if safe mode
is not enabled, executes the code reference with the given parameters. The code
reference is evaluated in the context (void, scalar, or list) in which B<action>
was called.

In safe mode, the integer 1 is returned, otherwise the return value is that
of the code reference.

=cut

sub action {
    my ( $message, $code, @args ) = @_;
    $code and ref $code eq 'CODE'
      or croak 'Usage: Conform::Core::IO::HTTP::action($message, \&code, @args)';

    if ($safe_mode) {
        note "SKIPPING: $message\n" if $message;
        return 1;
    }
    else {
        note "$message\n" if $message;
        return $code->(@args);
    }
}

=item B<safe>

    $result = safe \&code, @args;

If safe mode is not enabled executes the code reference with the given
parameters.

Exactly equivalent to:

    $result = action '' => \&code, @args;

=cut

sub safe {
    $_[0] and ref $_[0] eq 'CODE'
      or croak 'Usage: Conform::Core::IO::HTTP::safe(\&code, @args)';
    action '' => @_;
}

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

sub _timeout {
    my ( $timeout, $code ) = @_;
    unless ($timeout) {
        $code->();
        return 0;
    }

    my $alarm = alarm 0;
    my $err   = do {
        local $SIG{ALRM} = sub { die "alarm\n" };
        alarm $timeout;
        eval { $code->() };
        $@;
    };
    alarm $alarm;
    if ($err) {
        die $err unless $err eq "alarm\n";
        undef $@;
        return 1;
    }

    return 0
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

        debug lines_prefix( 'CMD: ', $text );

        $nl = $text =~ m/\n\z/;
        return 1
    }
}

sub command {
    my $flags = {};
    $flags = pop @_ if @_ and ref $_[-1] eq 'HASH';

    my @command = @_;
    @command and defined $command[0]
      or croak 'Usage: Conform::Core::IO::HTTP::command($command, @args, \%flags)';

    my $command = join ' ', @command;

    $flags->{intro}   ||= '';
    $flags->{success} ||= '';
    $flags->{failure} ||= $flags->{failure} = "FAILED: '$command' failed";
    $flags->{capture} = 1 unless exists $flags->{capture};
    $flags->{timeout}      ||= undef;
    $flags->{read_timeout} ||= $flags->{timeout};
    $flags->{wait_timeout} ||= $flags->{timeout};
    $flags->{kill_timeout} = 10 unless exists $flags->{kill_timeout};

    local $safe_mode = $safe_mode;
    $safe_mode = 0 if $flags->{nosafe};

    my $result = action(
        $flags->{note} => sub {
            debug $flags->{intro} if $flags->{intro};

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

                while ( _timeout($timeout, $code) ) {
                    warn "[timeout -- sending SIG$signame]\n";
                    kill $signal, $child;
                    ( $signame, $signal ) = ( KILL => SIGKILL );
                    $timeout = $flags->{kill_timeout};
                    $code = sub { waitpid $child, 0 };
                }

            }

            if ( $? >> 8 ) {
                warn "$flags->{failure}  Exit code: " . ( $? >> 8 ) . "\n";
            }
            elsif ($?) {
                warn "$flags->{failure}  Signal: " . ( $? & 0x7f ) . "\n";
            }
            elsif ( $flags->{success} ) {
                debug $flags->{success};
            }

            return $?
        }
    );

    return $safe_mode ? 0 : $result;
}

=item B<slurp_file>

    $content = slurp_file $filename;
    @lines   = slurp_file $filename;

Reads and returns the contents of the specified file. In scalar context, returns
the entire contents. In list context, returns a list of lines according to the
C<$/> special variable (just like C<readline> or the C<< <EXPR> >> operator).

If the filename begins with the string C<"http://"> then it is passed off to
B<slurp_http> instead.

=cut

sub slurp_file {
    my $filename = shift;
    defined $filename
      or croak 'Usage: Conform::Core::IO::HTTP::slurp_file($filename)';

    return slurp_http $filename if $filename =~ m(^http://);

    my $fh = IO::File->new( $filename, '<' )
      or die "Could not open $filename: $!\n";
    wantarray ? <$fh> : do { local $/; <$fh> };
}

sub _parse_time {
    my ( $d, $m, $Y, $H, $M, $S ) =
      $_[0] =~ m{^..., (\d\d) (...) (\d\d\d\d) (\d\d):(\d\d):(\d\d) GMT$}m
      or return;

    $Y -= 1900;

    $m = {
        jan => 0,
        feb => 1,
        mar => 2,
        apr => 3,
        may => 4,
        jun => 5,
        jul => 6,
        aug => 7,
        sep => 8,
        oct => 9,
        nov => 10,
        dec => 11,
      }->{ lc $m }
      or return;

    return timegm $S, $M, $H, $d, $m, $Y;
}

=item B<slurp_http>

    $content = slurp_http $uri, \%flags;
    @lines   = slurp_http $uri, \%flags;

Retrieves the specified URI and returns its contents. In scalar context, returns
the entire contents. In list context, returns a list of lines according to the
C<$/> special variable (just like C<readline> or the C<< <EXPR> >> operator).

Downloaded files are cached in F</var/cache/conform>.

An optional flags hashref may be supplied as the last argument. The following
flags are recognized:

=over

=item I<cache>

Specifies an HTTP cache directory. If set to C<undef>, no cache directory
is used. If not specified, a default system-wide cache directory is used.

=item I<reload>

If set, force a reload of the document from the origin server even if it is
present in the HTTP cache.

=back

=cut

sub safe_write_file;

sub slurp_http {
    my ( $uri, $flags ) = @_;
    $flags ||= {};

    defined $uri and ref $flags eq 'HASH'
      or croak 'Usage: Conform::Core::IO::HTTP::slurp_http($uri, \%flags)';

    my $key = md5_hex $uri;
    my $cache =
      exists $flags->{cache}
      ? $flags->{cache}
      : HTTP_CACHE;

    my ( $cache_file, $metadata_file );
    if ( defined $cache ) {
        my $key = md5_hex $uri;
        $cache_file    = "$cache/$key";
        $metadata_file = "$cache/$key.metadata";
    }

    my $now = time();

    my $metadata;
    if (    not $flags->{reload}
        and defined $cache
        and -f $cache_file
        and -f $metadata_file )
    {
        $!        = 0;
        $metadata = do $metadata_file;
        if ( defined $metadata ) {
            unless ( ref $metadata eq 'HASH' ) {
                warn "Invalid metadata in $metadata_file\n";
                undef $metadata;
            }
        }
        else {
            $!
              ? warn "Could not read $metadata_file: $!\n"
              : warn "Could not compile $metadata_file: $@\n";
        }
    }

    if ($metadata) {
        my $fresh;
        if ( defined $metadata->{max_age} ) {
            $fresh++ if ($now - $metadata->{requested} < $metadata->{max_age});
        }
        elsif ( defined $metadata->{expires} ) {
            $fresh++ if ($now < $metadata->{expires});
        }

        return slurp_file $cache_file if $fresh;

        delete $metadata->{expires};
        delete $metadata->{max_age};
    }

    debug "Requesting $uri";

    my $ua = LWP::UserAgent->new(
        agent     => "conform/$VERSION",
        timeout   => HTTP_TIMEOUT,
        env_proxy => 1,  # use proxy settings in %env
    );

    my $req = HTTP::Request->new(GET => $uri);

    if ($metadata) {
        $req->header('If-Modified-Since' => time2str($metadata->{last_modified}))
            if defined $metadata->{last_modified};

        $req->header('If-None-Match' => $metadata->{etag})
            if defined $metadata->{etag};
    }

    my $res = $ua->request($req);

    $metadata ||= {};

    my $code = $res->code;
    $code == 200
        or $code == 304
        or die sprintf( 'Unexpected HTTP code: %d or %s, Status: %s'."\n", $code, $uri, $res->status_line);

    my $body = $res->content;

    if (    $code == 200
        and $res->header('Content-Length') )
    {
        my $content_length = $res->header('Content-Length');
        my $length         = length $body;
        $content_length == $length
          or die
          "Content length mismatch; header has $content_length, got $length\n";
    }

    $metadata->{requested}     = $now;
    $metadata->{last_modified} = _parse_time($res->header('Last-Modified'))
      if $res->header('Last-Modified');
    $metadata->{expires} = _parse_time($res->header('Expires'))
      if $res->header('Expires');
    # FIXME
    # $metadata->{max_age} = 0 + $res->headers('Cache-Control')
    #  if $res->headers('Cache-Control');
    # WAS $headers =~ m{\015?\012 Cache-Control: (?:.*,)?[\040\t]* max-age=(\d+) }xmi;
    $metadata->{etag} = $1
      if ($res->header('Etag') and $res->header('Etag') =~ m/^"?([A-z\-]+)"?$/);

    $metadata->{md5} = md5_hex $body;
    $metadata->{sha1} = sha1_hex $body;

    unless ( defined $cache ) {
        return $body unless wantarray;
        return $body unless defined $/;
        if ( ref $/ eq 'SCALAR' ) {
            my $len = 0 + ${$/};
            return $body if $len <= 0;
            return $body =~ m/(.{1,\Q$len\E})/sg;
        }
        return $body =~ m/(.+?(?:\z|\n\n))\n*/sg if $/ eq '';
        return split m{(?<=\Q$/\E)}, $body;
    }

    {
        local $safe_mode = 0;
        safe_write_file( $metadata_file,
          Data::Dumper->new( [$metadata] )->Terse(1)->Indent(0)->Dump);
        safe_write_file( $cache_file, $body ) if $code == 200;
    }

    return slurp_file $cache_file;
}

=item B<safe_write>, B<safe_write_file>

    safe_write      $filename, @lines, \%flags;
    safe_write      $filename, \*FH,   \%flags;
    safe_write_file $filename, @lines, \%flags;
    safe_write_file $filename, \*FH,   \%flags;

If safe mode is not enabled writes out a file. The contents of the file can
be specified as a list of lines or as a file handle. B<safe_write> also checks
the file into RCS.

If no I<mode> flag is specified, the file's mode is taken from the previous
version of the file, or, if that doesn't exist, it is set to 0666 modified by
the process' umask.

An optional flags hashref may be supplied as the last argument. The following
flags are recognized:

=over

=item I<note>

Message to be logged prior to writing out the file. (This is used as the message
in B<action>.)

=item I<mode>, I<owner> or I<uid>, I<group> or I<gid>, I<quiet>

Passed to B<set_attr> (see below) when setting the attributes of the file.

=back

=cut

sub dir_check;
sub set_attr;
sub get_attr;

sub safe_write {
    defined $_[0]
      or croak 'Usage: Conform::Core::IO::HTTP::safe_write($filename, @lines, \%flags)';

    my ( $dirname, $filename ) = $_[0] =~ m/(?:(.*)\/)?(.*)/;
    $dirname ||= '.';

    my $flags;
    $flags = pop @_ if ( @_ and ref $_[-1] eq 'HASH' );

    my %reset   = ();
    my $changed = 0;

    if ( -f "$dirname/$filename" ) {

        # work around a quirk in rcs < 5.7.33, which doesn't preserve
        # permissions

        # save attr
        %reset = get_attr( \*_ );

        dir_check "$dirname/RCS", { mode => 0700 };
        command $ci, '-q', '-mUntracked Changes',
          '-t-Initial Checkin',
          '-l', "$dirname/$filename";

        # reset attr
        $reset{quiet}++;
        set_attr "$dirname/$filename", \%reset;

    }

    $changed += safe_write_file @_, $flags;

    if ( -f "$dirname/$filename" ) {

        # save attr
        %reset = get_attr( \*_ );

        dir_check "$dirname/RCS", { mode => 0700 };
        command $ci, '-q', "-m$safe_write_msg", '-t-Initial Checkin',
          '-l', "$dirname/$filename";

        # reset attr
        $reset{quiet}++;
        set_attr "$dirname/$filename", \%reset;
    }

    return $changed;

}

sub safe_write_file {
    my $filename = shift @_;
    defined $filename
      or croak
      'Usage: Conform::Core::IO::HTTP::safe_write_file($filename, @lines, \%flags)';

    my $flags = {};
    $flags = pop @_ if @_ and ref $_[-1] eq 'HASH';

    my $note = delete $flags->{note};

    return action $note => sub {

        my @args = @_;

        my $noisy = 0;
        if ( -f $filename ) {

            # preserve attributes of existing file
            # unless we were explicitly told to change
            my %attr = get_attr( \*_ );
            for ( keys %attr ) {
                if ( exists $flags->{$_}
                    and $flags->{$_} != $attr{$_} )
                {

                    # we've been told to change/set
                    $noisy++;
                }
                else {

                    # preserve
                    $flags->{$_} = $attr{$_};
                }
            }
            if ($attr{immutable}) {
                # this will need to be wrapped in the future for non-linux
                _clear_ext2_immutable($filename);
            }
            if ($attr{append_only}) {
                # this will need to be wrapped in the future for non-linux
                _clear_ext2_append_only($filename);
            }

            $flags->{quiet} = !$noisy unless exists $flags->{quiet};
        }

        my $fh = IO::File->new( "$filename.$$", '>' )
          or die "Unable to open $filename.$$ for writing: $!\n";

        # If the argument is a filehandle, use that.
        if ( ref $args[0] and defined fileno $args[0] ) {
            my $in = shift @args;
            while (<$in>) {
                $fh->print($_)
                  or die "Could not write to $filename.$$: $!\n";
            }
        }
        else {
            $fh->print(@args)
              or die "Could not write to $filename.$$: $!\n";
        }

        $fh->close
          or die "Could not close $filename.$$: $!\n";

        rename "$filename.$$" => $filename
          or die "Could not rename $filename.$$ to $filename: $!\n";

        return set_attr $filename, $flags
          if grep exists $flags->{$_},
          qw(mode owner uid group gid);

        1;
    }, @_;
}

=item B<set_attr>

    $updated = set_attr $filename, \%flags;

If safe mode is not enabled, updates the mode and ownership of the specified
file. If the attributes of the file are updated, returns true.

The flags hashref is mandatory. The following flags are recognized:

=over

=item I<mode>

A set of permissions to apply to the file. The value may be either numeric or
a symbolic, as recognized by C<chmod(1)>.

=item I<owner> or I<uid>, I<group> or I<gid>

A new user and/or group to apply to the file. The values may be either numeric
or a valid system user or group.

=item I<immutable>

If this flag is set on a file, even root cannot change the files content
without first removing the flag.

This is filesystem dependant, will croak if not supported.

=item I<append_only>

If this flag is set on a file then its contents can be added to but not
removed unless the flag is first removed.

This is filesystem dependant, will croak if not supported.

=item I<quiet>

If set, when updating attributes do not print any status messages.

=back

=cut

sub _set_ext2_attributes {
  my $file = shift;
  my $flags = shift;
  my $fh;
  if (ref $file and ref $file eq 'GLOB') { $fh = $file; }
  else { (open $fh, '>', $file) or return; }
  my $flag = pack 'i', $flags;
  return unless defined ioctl($fh, EXT2_IOC_SETFLAGS, $flag);
}

sub _set_ext2_immutable {
    my $filename = shift or return;
    my $flags = _get_ext2_attributes($filename);
    return unless defined $flags;
    return _set_ext2_attributes($filename, $flags | EXT2_IMMUTABLE_FL)
}

sub _clear_ext2_immutable {
    my $filename = shift or return;
    my $flags = _get_ext2_attributes($filename);
    return unless defined $flags;
    return _set_ext2_attributes($filename, $flags | ~EXT2_IMMUTABLE_FL)
}

sub _set_ext2_append_only {
    my $filename = shift or return;
    my $flags = _get_ext2_attributes($filename);
    return unless defined $flags;
    return _set_ext2_attributes($filename, $flags | EXT2_APPEND_FL)
}

sub _clear_ext2_append_only {
    my $filename = shift or return;
    my $flags = _get_ext2_attributes($filename);
    return unless defined $flags;
    return _set_ext2_attributes($filename, $flags | ~EXT2_APPEND_FL)
}

sub set_attr {
    my ( $filename, $flags ) = @_;
    defined $filename and $flags and ref $flags eq 'HASH'
      or croak 'Usage: Conform::Core::IO::HTTP::set_attr($filename, \%flags)';

    my ( $mode, $uid, $gid, $immutable, $append_only );

    for ( $flags->{mode} ) {
        last unless defined;
        if (m/^\d+$/) {
            $mode = $_ & 07777;
        }
        elsif (/^([r-][w-][stx-]){3}$/) {
            $mode = 0;
            my $shift = 2;
            for (/^(...)(...)(...)$/) {
                $mode |= 1 << ( 9 + $shift )         if s/[st]/x/;
                $mode |= 1 << ( ( $shift * 3 ) + 2 ) if /r/;
                $mode |= 1 << ( ( $shift * 3 ) + 1 ) if /w/;
                $mode |= 1 << ( $shift * 3 )         if /x/;
                $shift--;
            }
        }
        else {
            croak "Invalid mode for $filename: $_";
        }
    }

    for ( $flags->{owner} || $flags->{uid} ) {
        last unless defined;
        if (m/^\d+$/) {
            $uid = $_;
        }
        else {
            $uid = getpwnam $_;
            defined $uid
              or croak "Unknown user for $filename: $_";
        }
    }

    for ( $flags->{group} || $flags->{gid} ) {
        last unless defined;
        if (m/^\d+$/) {
            $gid = $_;
        }
        else {
            $gid = getgrnam $_;
            defined $gid
              or croak "Unknown group for $filename: $_";
        }
    }

    for ( $flags->{immutable} ) {
        last unless defined;
        croak "Setting of immutable flag not handled in $^O"
            unless $^O eq 'linux';
        $immutable = $_;
    }

    for ( $flags->{append_only} ) {
        last unless defined;
        croak "Setting of append_only flag not handled in $^O"
            unless $^O eq 'linux';
        $append_only = $_;
    }

    return 0 unless defined $mode
                 or defined $uid
                 or defined $gid
                 or defined $immutable
                 or defined $append_only;

    my @stat = stat $filename;
    unless (@stat) {
        die "Could not stat $filename: $!\n" unless $safe_mode;
        return 0;
    }

    my $changed = 0;
    if ( defined $mode and ( $stat[2] & 07777 ) != $mode ) {
        my $omode = sprintf '%03o', $mode;
        my $note =
          $flags->{quiet} ? '' : "Changing mode of $filename to $omode";
        $changed += action $note => sub {
            chmod $mode, $filename
              or die "chmod $omode $filename failed: $!\n";
        };
    }

    # ! defined $uid : no uid was supplied in the $flags hashref
    # $stat[4] == $uid : the file is already owned by this uid
    if ( !defined $uid || $stat[4] == $uid ) { $uid = -1; }
    if ( !defined $gid || $stat[5] == $gid ) { $gid = -1; }

    # perldoc -f chown LIST: The first two elements of the list
    # must be the *numeric* uid and gid, in that order. A value
    # of -1 in either position is interpreted by most
    # systems to leave that value unchanged.

    # if both $uid and $gid are -1, the file already has the $uid and $gid
    # that we're asking for, no action needed. If either is not -1,
    # do a chown.
    if ( $uid != -1 or $gid != -1 ) {
        my $note =
          $flags->{quiet} ? '' : "Changing ownership of $filename to $uid:$gid";
        $changed += action $note => sub {
            chown $uid, $gid, $filename
              or die "chown $uid:$gid $filename failed: $!\n";
        };
    }

    if (defined $immutable) {
        my $note = '';
        unless ($flags->{quiet}) {
            if ($immutable) {
                $note = "Setting immutable flag on $filename";
            } else {
                $note = "Clearing immutable flag on $filename";
            }
        }
        $changed += action $note => sub {
            if ($immutable) { return _set_ext2_immutable($filename) }
            else { return _clear_ext2_immutable($filename) }
        };
    }

    if (defined $append_only) {
        my $note = '';
        unless ($flags->{quiet}) {
            if ($append_only) {
                $note = "Setting append only flag on $filename";
            } else {
                $note = "Clearing append only flag on $filename";
            }
        }
        $changed += action $note => sub {
            if ($append_only) { return _set_ext2_append_only($filename) }
            else { return _clear_ext2_append_only($filename) }
        };
    }

    return $changed
}

=item B<get_attr>

    %attr = get_attr $filename;
    %attr = get_attr \*FH;

Returns a HASH with the mode, uid and gid of a file or filehandle.
Also includes the immutable and append_only file, depending on the
underlying filesystem. (absent if not supported or not supported by
this function)

Returns an empty list if the file does not exist
or the filehandle is undef.

=cut

sub _get_ext2_attributes {
  my $file = shift;
  my $fh;
  if (ref $file and ref $file eq 'GLOB') {
     return unless fileno $file and tell($file) != -1;
     $fh = $file; }
  else { open( $fh, '<', $file ) or return; }
  my $res = pack 'i', 0;
  return unless defined ioctl($fh, EXT2_IOC_GETFLAGS, $res);
  $res = unpack 'i', $res;
  return $res
}

sub get_attr {

    my $f = shift or return;
    my %attr;

    if ( ref $f and ref $f eq 'GLOB' ) {
        @attr{qw(mode uid gid)} = ( stat($f) )[ 2, 4, 5 ];

    }
    elsif ( !ref $f and -f $f ) {
        @attr{qw(mode uid gid)} = ( stat($f) )[ 2, 4, 5 ];
    }
    elsif ( !ref $f ) {
        return
    }
    else {
        croak 'usage: get_attr (\*HANDLE)';
    }

    ## This is a nasty assumption, but its a cheap assumption.
    ## We use ioctls from the EXT2 headers, so linux only is close
    if ($^O eq 'linux') {
        my $flags = _get_ext2_attributes($f);
        if (defined $flags) {
            $attr{immutable}   = $flags & EXT2_IMMUTABLE_FL;
            $attr{append_only} = $flags & EXT2_APPEND_FL;
        }
    }

    $attr{mode} &= 07777 if exists $attr{mode};

    return %attr;
}

=item B<text_install>, B<file_install>, B<http_install>

    $updated = text_install $filename, $text,   $cmd, \%flags;
    $updated = file_install $filename, $source, $cmd, \%flags, @expr;
    $updated = http_install $filename, $uri,    $cmd, \%flags, @expr;

If safe mode is not enabled, writes out the specified file with contents from a
literal string, another file, or a URI respectively. If the file's contents are
changed, the command C<$cmd> is executed and a true value is returned.

If C<@expr> is specified, B<file_install> and B<http_install> can perform
on-the-fly transformations of the file contents. See B<file_modify> below for
details on how transformations are processed.

An optional flags hashref may be supplied as the last argument. The following
flags are recognized:

=over

=item I<srcfn>

A "filename" describing the input. This is used in status messages. If omitted,
a useful default is used instead.

=item I<rcs>

Whether version control should be applied to the file. If omitted, version
control is applied.

=back

Other flags will be passed to B<set_attr>.

=cut

sub _filter_rcs_id { # added on sirz 52319
 #first arg turns this filter on or off
 return @_ unless shift;
 return map { my $f = shift;
              $f =~ s/\$Author.*\$/\$Author\$/g;
              $f =~ s/\$Date.*\$/\$Date\$/g;
              $f =~ s/\$Header.*\$/\$Header\$/g;
              $f =~ s/\$Id.*\$/\$Id\$/g;
              $f =~ s/\$Locker.*\$/\$Locker\$/g;
              $f =~ s/\$Log.*\$/\$Log\$/g;
              $f =~ s/\$Name.*\$/\$Name\$/g;
              $f =~ s/\$RCSfile.*\$/\$RCSfile\$/g;
              $f =~ s/\$Revision.*\$/\$Revision\$/g;
              $f =~ s/\$Source.*\$/\$Source\$/g;
              $f =~ s/\$State.*\$/\$State\$/g;
              $f } @_
}

sub text_install {
    my ( $filename, $text, $cmd, $flags ) = @_;
    $flags ||= {};

    defined $filename and defined $text and ref $flags eq 'HASH'
      or croak
      'Usage: Conform::Core::IO::HTTP::text_install($filename, $text, $cmd, \%flags)';

    $flags->{srcfn} ||= 'text';
    $flags->{rcs} = 1 unless exists $flags->{rcs};

    # create containing directory if it doesn't exist
    ( my $path = $filename ) =~ s{/[^/]+$}{};
    dir_check $path if $path;

    my $changed = 1;

    # If they are the same, don't bother ..
    #   and they can't have the same md5 if they're different sizes ..
    if ( -f $filename and ($flags->{rcs} or -s $filename == length($text) ) ) {
        my $src_md5 = Digest::MD5->new->add( _filter_rcs_id($flags->{rcs},$text) )->hexdigest;
        my $filename_md5 =
          Digest::MD5->new->add( _filter_rcs_id($flags->{rcs},slurp_file($filename) ))->hexdigest;

        $changed = 0 if $src_md5 eq $filename_md5;
    }

    if ($changed) {
        if ( $flags->{rcs} ) {
            safe_write $filename, $text,
              { note => "Installing '$filename' from $flags->{srcfn}" };
        }
        else {
            safe_write_file $filename, $text,
              { note =>
                  "Installing '$filename' from $flags->{srcfn} (skipped RCS)" };
        }
    }

    $changed += set_attr $filename, $flags;
    if ( $changed and defined $cmd ) {
        command $cmd,
          { note => "Running '$cmd' to finish install of $filename" };
    }

    return $changed
}

sub http_install;

sub file_install {
    my ( $filename, $source, $cmd, $flags, @expr ) = @_;
    $flags ||= {};

    defined $filename and defined $source and ref $flags eq 'HASH'
      or croak
'Usage: Conform::Core::IO::HTTP::file_install($filename, $source, $cmd, \%flags, @expr)';

    return http_install @_ if $source =~ m(^http://);

    my $caller_package = (caller)[0];

    my $text = '';
    if (@expr) {
        my $fh = IO::File->new( $source, '<' )
          or die "Could not open $source: $!\n";

        local $_;
        while (<$fh>) {
            for my $e (@expr) {
                if ( $e and ref $e eq 'CODE' ) {
                    $e->();
                }
                else {
                    eval "package $caller_package; { $e }; 1"
                      or die $@;
                }
            }
            $text .= $_;
        }
    }
    else {
        $text = slurp_file $source;
    }

    return text_install $filename, $text, $cmd, { srcfn => $source, %$flags };
}

sub http_install {
    my ( $filename, $uri, $cmd, $flags, @expr ) = @_;
    $flags ||= {};

    defined $filename and defined $uri and ref $flags eq 'HASH'
      or croak
'Usage: Conform::Core::IO::HTTP::http_install($filename, $uri, $cmd, \%flags, @expr)';

    if ( $filename =~ m/^\Q@{[HTTP_CACHE]}/ ) {
        _deprecated http_install =>
          'Conform::Core::IO::HTTP::http_install should not be used to write to HTTP cache';
        return 1;
    }

    my $caller_package = (caller)[0];

    my $text = '';
    if (@expr) {
        for ( slurp_http( $uri, $flags ) ) {
            for my $e (@expr) {
                if ( $e and ref $e eq 'CODE' ) {
                    $e->();
                }
                else {
                    eval "package $caller_package; { $e }; 1"
                      or die $@;
                }
            }
            $text .= $_;
        }
    }
    else {
        $text = slurp_http( $uri, $flags );
    }

    return text_install $filename, $text, $cmd, { srcfn => $uri, %$flags };
}

=item B<file_audit>

    $updated = file_audit $filename, \%flags;

Writes audit rules to C</etc/audit/audit.rules> in the format...

C<-w $filename -p $flags{perm}>

An optional \%flags hashref may be supplied as the last argument.
The following flags are recognized:

B<$flags{perm}> - Permission filter. Defaults to C<w>. See the C<-p>
flag in the C<auditctl> man page.

B<$flags{file}> - Location of the C<audit.rules> file. Defaults to
C</etc/audit/audit.rules>.

The user should be aware that auditing large directory trees that
generates a lot of deltas can cause a significat kernel overhead.

=cut

sub file_audit {
    my ($filename, $flags) = @_;
    my $perm = $flags->{perm} || 'w';
    my $file = $flags->{file} || '/etc/audit/audit.rules';
    die "Invalid perm '$perm'\n" if not $perm =~ m/^(?:r|w|x|a)+$/;

    file_append( $file, "-w $filename -p $perm\n", "^\-w $filename " );

    return 1;
}

=item B<dir_list>

    @filenames = dir_list $path, \%flags;
    $filenames = dir_list $path, \%flags;

Retrieve a directory listing at $path.
Returns an array in list context and an arrayref in scalar context.
Dies if $path is not a directory.

B<NB> '.' and '..' are never returned in a directory listing.

The following flags are supported:

=over

=item I<include>

A 'Regexp' or 'sub' that can be used to filter results.
If a 'Regexp' is passed the full path name of each file will be matched against for
inclusion in the returned listing.
If a 'sub' is passed, it will be called with the following parameters in order:

=over 4

=item I<pathname_filename>  The full name of the file I.e. $path/$file

=item I<pathname> The path name. I.e. $path

=item I<filename> The file name. I.e. $file

If the 'sub' returns a true value, the $file will be 'included' in the directory
listing.

If include is provided,  anything that doesn't match will be excluded.
B<Please Note:> The default is to include everything.

=back

=item I<exclude>

A 'Regexp' or 'sub' that can be used to filter results.
If a 'Regexp' is passed the full path name of each file will be matched against for
exclusion of the directory listing.
If a 'sub' is passed, it will be called with the following parameters in order:

=over 4

=item I<pathname_filename>  The full name of the file I.e. $path/$file

=item I<pathname> The path name. I.e. $path

=item I<filename> The file name. I.e. $file

If the 'sub' returns a true value, the $file will be 'excluded' from the directory
listing.

=back

=item I<filter_order>

A string, which controls the include/exclude behaviour. Valid values are
'include,exclude', or 'exclude,include'.  The default is "I<include,exclude>".

As the name suggests, depending on the value passed in, the include, or exclude
tests will be done in that order.

=item I<recurse>

A boolean, which signifies whether or not to recurse into subdirectories.
If 'true', the the full path name of each file in each subdirectory,
depending on include,exclude filters will be included in the directory listing.

=item I<recurse_first>

A boolean, which controls the semantics of recursion and filtering.
If allows you to 'include' files which would have otherwise been
excluded due to filtering, by recursing into each directory before
applying filtering rules.

B<Please Note:> 'recurse_first' implies 'recurse', and only
has an effect, when include or exclude filters are provided.

=back

=cut

sub __dir_list;

sub __dir_list {
    my ( $path, $open_dir, $read_dir, $recurse, $files ) = @_;
    ( scalar caller ) eq __PACKAGE__
      or croak "Private subroutine";

    my $handle = $open_dir->($path)
      or return;

  FILE: while ( defined( local $_ = $read_dir->( $handle, $path ) ) ) {
        next if /^[.]{1,2}\/?$/;    # filter out '.' and '..' by default
        push @$files, ( my $file = $_ );
        if ( $recurse and $file =~ m/\/$/ ) {
            my @files = ();
            __dir_list "${path}${file}", $open_dir, $read_dir, $recurse, \@files
              or return;

            push @$files, ( map ( "${file}${_}", @files ) )
              if @files;
        }
    }

    return 1
}

##
# __dir_list_filtered
# Generate a directory listing with include, exclude filtering and
# optional recursion.  This is an internal sub called by
# _dir_list.
# $path (SCALAR) is the path to get a 'directory' listing for
# $open_dir (CODE) is a callback to open a 'directory'
# $read_dir (CODE) is a callback to read the next 'directory' entry
# $recurse (SCALAR) (a tri-state variable) signals whether or not to recurse and how to recurse.
#    $recurse < 0 implies recursion before filtering
#    $recurse > 0 implies filtering before recursion
#    $recurse = 0 implies no recursion
# $filters (HASH) are the 'include' => 'CODE', 'exclude' => 'CODE' filters to apply to check for inclusion
# $order (ARRAY) determines the order the filter should be applied. I.e. ('exclude', 'include') or ('include','exclude')
# $files (ARRAY) an optional list of files, to be used when being called recursively.
##
sub __dir_list_filtered;

sub __dir_list_filtered {
    my ( $path, $open_dir, $read_dir, $recurse, $filters, $order, $files ) = @_;
    ( scalar caller ) eq __PACKAGE__
      or croak "Private subroutine";

    my $handle = $open_dir->($path);

    defined $handle
      or die "Conform::Core::IO::HTTP::dir_list error opendir error :$!";

  FILE: while ( defined( my $file = $read_dir->( $handle, $path ) ) ) {
        next if $file =~ m/^[.]{1,2}\/?$/;   # filter out '.' and '..' by default
        my @files;

        # if recurse_first and is a directory
        if ( $recurse < 0 and $file =~ m/\/$/ ) {
            return
              unless ( __dir_list_filtered "${path}${file}",
                $open_dir, $read_dir, $recurse, $filters, $order, \@files );

        }

      FILTER: for my $type (@$order) {
            next FILTER unless defined $filters->{$type};
            my $match =
              $filters->{$type}->( "${path}${file}", my $pathname = $path,
                my $filename = $file );
            last FILTER if $match and $type eq 'include';

            ###
            # This will exclude directories, even if
            # they could match a file specified by 'include'
            next FILE
              if ( ( $recurse >= 0 ) && ( !$match and $type eq 'include' )
                || ( $match and $type eq 'exclude' ) );

            ####
            # These will add match @files (due to recursion) even if the current '$file'
            # won't be inluded, due to 'include', or 'exclude' filtering.
            if (   ( $recurse < 0 ) && ( !$match and $type eq 'include' )
                || ( $match and $type eq 'exclude' ) )
            {

                push @$files, ( map( "${file}${_}", @files ) )
                  if @files;

                next FILE;
            }
        }

        # $file passed all tests with flying colours - so add it.
        push @$files, $file;

        # perform recursion 'post' filtering
        if ( $recurse > 0 and $file =~ /\/$/ ) {

            return
              unless ( __dir_list_filtered "${path}${file}",
                $open_dir, $read_dir, $recurse, $filters, $order, \@files );

        }

        # add any files found if there were any
        push @$files, ( map( "${file}${_}", @files ) )
          if @files;
    }

    return 1
}

##
# _dir_list
# Validate and normalise dir_list function parameters
# $path is the path to get a listing for
# $open_dir is a callback to open a 'directory'
# $read_dir is a callback to read the next 'directory' entry
# \%flags - See dir_list and dir_list_http for definition of \%flags
##
sub _dir_list {
    my ( $path, $open_dir, $read_dir, $flags ) = @_;
    $flags ||= {};

    $path and ref $flags eq 'HASH'
      or croak "usage: Conform::Core::IO::HTTP::dir_list (\$path, [\\\%flags])";

    $path = "$path/" unless $path =~ m{/$};

    my $include_sub;
    my $exclude_sub;

    my $include = $flags->{'include'};
    $include = qr/$include/
      if defined $include
          and length $include
          and not ref $include;

    $include_sub =
      defined $include
      ? (
        ref $include eq 'Regexp'
        ? sub { $_[0] =~ $include }
        : $include
      )
      : undef;

    my $exclude = $flags->{'exclude'};
    $exclude_sub =
      defined $exclude
      ? (
        ref $exclude eq 'Regexp'
        ? sub { $_[0] =~ $exclude }
        : $exclude
      )
      : undef;

    croak "'include' invalid for dir_list"
      if $include_sub and ref $include_sub ne 'CODE';

    croak "'exclude' invalid for dir_list"
      if $exclude_sub and ref $exclude_sub ne 'CODE';

    croak "'open_dir' sub is invalid"
      unless ref $open_dir eq 'CODE';

    croak "'read_dir' sub is invalid"
      unless ref $read_dir eq 'CODE';

    my $filter_order = $flags->{'filter_order'} || '';

    my %filters = ( include => $include_sub, exclude => $exclude_sub );
    my @filter_order =
      $filter_order eq 'exclude,include'
      ? (qw(exclude include))
      : (qw(include exclude));

    my $recurse       = $flags->{'recurse'}       || 0;
    my $recurse_first = $flags->{'recurse_first'} || 0;

    # recurse < 0 then recurse before filtering
    # recurse > 0 then recurse after filtering
    # recurse = 0 then don't recurse at all
    $recurse =
      $recurse_first
      ? -1
      : ( $recurse ? 1 : 0 );

    my @files = ();

    my $result =
      !( defined $include_sub ) && !( defined $exclude_sub )
      ? __dir_list $path, $open_dir, $read_dir, $recurse, \@files,
      : __dir_list_filtered $path,
      $open_dir,
      $read_dir,
      $recurse,
      { include => $include_sub, exclude => $exclude_sub },
      \@filter_order,
      \@files;

    die "_dir_list error: $!"
      unless $result;

    return wantarray ? @files : \@files;
}

sub dir_list {
    my ( $path, $flags ) = @_;
    $flags ||= {};

    $path =~ s!^file://!!;

    $path and -d $path
      or croak "$path is not a directory";

    my %seen = ();

    return _dir_list $path, sub {
        my $handle = IO::Dir->new();
        $handle->open( $_[0] )
          or return;
        return $handle;
      }, sub {
        while ( defined( my $file = $_[0]->read() ) ) {
            next if $file =~ m{^[\.]{1,2}\/?$};
            my $fullpath = $_[1] . $file;

            use Fcntl qw(:mode);
            my ( $inode, $mode ) = ( lstat $fullpath )[ 1, 2 ];
            my $is_dir  = S_ISDIR($mode);
            my $is_link = S_ISLNK($mode);

            if ($is_link) {
                my $link = readlink $fullpath;

                # warn "$fullpath is LINK ($link)\n";
            }

            if ( $inode && $inode != 0 ) {
                if ( $seen{$inode}++ ) {
                    warn "seen inode $inode for $file --skipping";
                    next;
                }

                $file = "$file/" if $is_dir;
                return $file;
            }
        }
        return;
      }, $flags;
}

=item B<dir_list_http>

    @filenames = dir_list_http $uri, \%flags;
    $filenames = dir_list_http $uri, \%flags;

Retrieve a directory listing at $uri over http.
Returns an array in list context and an arrayref in scalar context.
Dies if $uri is not a directory.

B<NB> '.' and '..' are never returned in a directory listing.

The following flags are supported:

=over

=item I<include>

A 'Regexp' or 'sub' that can be used to filter results.
If a 'Regexp' is passed the full path name of each file (including the uri) will be matched against for
inclusion in the returned listing.
If a 'sub' is passed, it will be called with the following parameters in order:

=over 4

=item I<uripathname_filename>  The full name of the file I.e. $uri/$file

=item I<uripathname> The path name. I.e. $uri

=item I<filename> The file name. I.e. $file

If the 'sub' returns a true value, the $file will be 'included' in the directory
listing.

If include is provided,  anything that doesn't match will be excluded.
B<Please Note:> The default is to include everything.

=back

=item I<exclude>

A 'Regexp' or 'sub' that can be used to filter results.
If a 'Regexp' is passed the full path name (including the uri) of each file will be matched against for
exclusion of the directory listing.
If a 'sub' is passed, it will be called with the following parameters in order:

=over 4

=item I<uripathname_filename>  The full name of the file I.e. $uri/$file

=item I<uripathname> The path name. I.e. $uri

=item I<filename> The file name. I.e. $file

If the 'sub' returns a true value, the $file will be 'excluded' from the directory
listing.

=back

=item I<filter_order>

A string, which controls the include/exclude behaviour. Valid values are
'include,exclude', or 'exclude,include'.  The default is "I<include,exclude>".

As the name suggests, depending on the value passed in, the include, or exclude
tests will be done in that order.

=item I<recurse>

A boolean, which signifies whether or not to recurse into subdirectories.
If 'true', the the full path name of each file in each subdirectory,
depending on include,exclude filters will be included in the directory listing.

=item I<recurse_first>

A boolean, which controls the semantics of recursion and filtering.
If allows you to 'include' files which would have otherwise been
excluded due to filtering, by recursing into each directory before
applying filtering rules.

B<Please Note:> 'recurse_first' implies 'recurse', and only
has an effect, when include or exclude filters are provided.

=back

=cut

# deprecated
sub _dir_list_http_parse_apache {
    defined $_[0]
      or croak "usage: _dir_list_http_parse_apache \$dir";
    while ( $_[0] =~
m/^(?:<tr><td valign="top">)?<img src="[^"]+" alt="[^"]+">(?:<\/td><td>| )?<a href="([^"]+)">(.+?)<\/a>(?:<\/td>| )/mg
      )
    {
        my ( $filename, $name ) = ( $1, $2 );
        next
          if !$filename || $name =~ m/Parent Directory/i || $filename =~ m/[\?#]/;
        $filename =~ s/([\r\n]).*$//;
        $filename =~ s/\n//g;
        $filename =~ s/\r//g;
        return $filename;
    }
    return;
}

##
# _dir_list_http_parse
# Extract relative links from a HTML document.
# Relative in this context means that the link
# is a "file" under this "directory"
sub _dir_list_http_parse {
    defined $_[0]
      or croak "usage: _dir_list_http_parse \$url";
    while ( $_[0] =~ m/<a href\s*=\s*(['"])?([^\?#\1]+?)\1>/mgi ) {
        my $link = $2;
        next if !$link || $link =~ m{^/} || $link =~ m{^http};
        if ( $_[-1]->{$link}++ ) {
            debug "seen $link -- skipping";
        }
        return $link;
    }
    return;
}

sub dir_list_http {
    my ( $uri, $flags ) = @_;
    $flags ||= {};

    my ( $scheme, $host, $port, $path ) =
      $uri =~ m{^(https?)://([^:/]+)(?::(\d+))?(/.*)$}
      or croak "Bad URI: $uri";

    $path = "$path/" unless $path =~ m{/$};

    $scheme and $host and $path
      or croak
      "Conform::Core::IO::HTTP::dir_list_http: $uri is invalid or is not a directory";

    my %seen = ();

    return _dir_list $uri, sub {
        my $html = eval { slurp_http $_[0], $flags; };
        if ( my $err = $@ ) {
            require Errno;
            if ( $err =~ m/404/ ) {
                $! = &Errno::ENOENT;
            }
            elsif ( $err =~ m/40[137]/ ) {
                $! = &Errno::EACCES;
            }
            else {
                warn "_dir_list $err";
                $! = &Errno::EREMOTEIO;
            }
            return;
        }
        return $html;
      }, sub {
        _dir_list_http_parse @_, \%seen;
      }, $flags;
}

=item B<file_append>

    $updated = file_append $filename, $line, $regex, $cmd, $create;

If safe mode is not enabled, append a line to the specified file
unless there is already a line matching C<$regex> that is identical to
$line. If the file's contents are changed, the command C<$cmd> is
executed and a true value is returned. If the file's contents are
changed, all lines matching C<$regex> are removed and C<$line> is
appended once, at the end of the file.  Before the comparison is made,
a newline is appended to $line if it does not end in a newline.

If C<$create> is set, the file will be created if it does not already exist.

=cut

sub file_append {
    my ( $filename, $line, $regex, $cmd, $create ) = @_;
    my ($regex_qm) = quotemeta($regex);    # handles \040 in fstab, SIR43953
          defined $filename
      and defined $line
      and $regex
      and ref($regex) =~ m/^(Regexp)?$/
      or croak
'Usage: Conform::Core::IO::HTTP::file_append($filename, $line, $regex, $cmd, $create)';

    if ( ( $line !~ m/$regex/ ) && ( $line !~ m/$regex_qm/ ) ) {
        croak "Can not append to $filename: '$line' does NOT match '$regex'";
    }

    # Avoid creating files that do not end with a newline:
    $line =~ s{([^\n])\z}{$1\n}xms;

    # only compare first line
    ( my $first = $line ) =~ s/\n.*$/\n/s;

    my $note = "Appending '$line' to $filename";

    my $text = '';

    if ( my $fh = IO::File->new( $filename, '<' ) ) {
        local $_;
        while (<$fh>) {
            if ( $regex && ( m/$regex/ || m/$regex_qm/ ) ) {

                # if the line we're looking at is identical to $first, the line
                # is already in the target file, and we will not append it or
                # modify the target file. Simply return 0
                return 0 if $_ eq $first;

                # If we reach here, $_ matches regex but is not identical
                # forget $_ and append $line to the end of the file, at [A]
            }
            else {
                $text .= $_;    # remember non-matching line
            }
        }
    }
    else {

        ($! == ENOENT and $create)
          or die "Could not open $filename: $!\n";
        $note .= ' (new file)';

        # create containing directory if it doesn't exist
        ( my $path = $filename ) =~ s{/[^/]+$}{};
        dir_check $path;

    }

    $text .= $line;             # [A] this is the actual appending of $line

    safe_write $filename, $text, { note => $note };

    if ( defined $cmd ) {
        command $cmd,
          { note => "Running '$cmd' to finish install of $filename" };
    }

    return 1
}

=item B<file_modify>

    $updated = file_modify $filename, $cmd, @expr;

If safe mode is not enabled, apply a sequence of transformations to the specifed
file. If the file's contents are changed, the command C<$cmd> is executed and a
true value is returned.

Each element of C<@expr> must be a coderef that modifies C<$_> or a string that
can be C<eval>ed to modify C<$_>. The file to modify is first read in. Then,
each line in the file is assigned to C<$_> in turn, the entire list of
transformations is executed, and the final value of C<$_> is saved for output.
Once all transformations have been completed, the output is saved back to the
file.

Transformation strings are C<eval>ed in the caller's package. Note also that
although these strings are C<eval>ed, any runtime errors are caught and
rethrown.

=cut

sub file_modify {
    my ( $filename, $cmd, @expr ) = @_;
    defined $filename
      or croak 'Usage: Conform::Core::IO::HTTP::file_modify($filename, $cmd, @expr)';

    my $caller_package = (caller)[0];

    my $changes;
    my $text = '';

    {
        my $fh = IO::File->new( $filename, '<' )
          or die "Could not open $filename: $!\n";

        local $_;
        while (<$fh>) {
            my $original = $_;
            for my $e (@expr) {
                if ( $e and ref $e eq 'CODE' ) {
                    $e->();
                }
                else {
                    eval "package $caller_package; { $e }; 1"
                      or die $@;
                }
            }
            $changes++ if $original ne $_;
            $text .= $_;
        }
    }

    return unless $changes;

    safe_write $filename, $text, { note => "Modifying $filename" };

    if ( defined $cmd ) {
        command $cmd,
          { note => "Running '$cmd' to finish install of $filename" };
    }

    return 1
}

=item B<file_unlink>

    $unlinked = file_unlink $filename, $cmd;

If safe mode is not enabled, unlinks the specified filename. If the file was
successfully unlinked, the command C<$cmd> is executed and a true value is
returned.

=cut

sub file_unlink {
    my ( $filename, $cmd, $flags ) = @_;
    $flags ||= {};
    defined $filename and ref $flags eq 'HASH'
      or croak 'Usage: Conform::Core::IO::HTTP::file_unlink($filename, $cmd, \%flags)';

    $flags->{rcs} = 1
      unless exists $flags->{rcs};

    ( my $dirname, $filename ) = $filename =~ m/(?:(.*)\/)?(.*)/;
    $dirname ||= '.';
    my $rcs = "$dirname/RCS/$filename,v";

    return unless -f "$dirname/$filename";

    if ( $flags->{rcs} ) {
        dir_check "$dirname/RCS", { mode => 0700 };
        command $ci, '-q', '-mUntracked Changes',
          '-t-Initial Checkin',
          '-l', "$dirname/$filename";
    }

    action "Unlinking $dirname/$filename" => sub {
        unlink "$dirname/$filename"
          or die "Could not unlink $dirname/$filename: $!\n";
    };

    if ( defined $cmd ) {
        command $cmd,
          { note => "Running '$cmd' to finish removal of $dirname/$filename" };
    }

    return 1
}

=item B<file_comment_spec>, B<file_comment>

    $updated = file_comment_spec $filename, $comment, $cmd, @regex;
    $updated = file_comment      $filename,           $cmd, @regex;

If safe mode is not enabled, comment out lines of the specified file matching
any of the regexes. If the file's contents are changed, the command C<$cmd> is
executed and a true value is returned.

The C<$comment> parameter to B<file_comment_spec> must be a string that may be
prefixed to lines to comment them out. B<file_comment> is exactly equivalent to
B<file_comment_spec> with C<$comment> set to C<"#">.

=cut

sub file_comment_spec {
    my ( $filename, $comment, $cmd, @regex ) = @_;
    defined $filename and defined $comment
      or croak
'Usage: Conform::Core::IO::HTTP::file_comment_spec($filename, $comment, $cmd, @regex)';

    return file_modify $filename, $cmd, sub {
        unless (m/^\Q$comment/) {
            for my $r (@regex) {
                if (m/$r/) {
                    s/^/$comment/;
                    last;
                }
            }
        }
    }
}

sub file_comment {
    my $filename = shift;
    defined $filename
      or croak 'Usage: Conform::Core::IO::HTTP::file_comment($filename, $cmd, @regex)';
    return file_comment_spec( $filename, '#', @_ );
}

=item B<file_uncomment_spec>, B<file_uncomment>

    $updated = file_comment_spec $filename, $comment, $cmd, @regex;
    $updated = file_comment      $filename,           $cmd, @regex;

If safe mode is not enabled, remove comments from lines of the specified file
matching any of the regexes. If the file's contents are changed, the command
C<$cmd> is executed and a true value is returned.

The C<$comment> parameter to B<file_uncomment_spec> must be a string or regular
expression describing the prefix to remove from the beginning of lines to
uncomment them. B<file_uncomment> is exactly equivalent to
B<file_uncomment_spec> with C<$comment> set to C<"#">.

=cut

sub file_uncomment_spec {
    my ( $filename, $comment, $cmd, @regex ) = @_;
    defined $filename and defined $comment
      or croak
'Usage: Conform::Core::IO::HTTP::file_uncomment_spec($filename, $comment, $cmd, @regex)';

    $comment = qr/$comment/ unless ref $comment eq 'Regexp';

    return file_modify $filename, $cmd, sub {
        if ( my ($rest) = m/^$comment(.*)/s ) {
            for my $r (@regex) {
                if ( $rest =~ m/$r/ ) {
                    $_ = $rest;
                    last;
                }
            }
        }
    };
}

sub file_uncomment {
    my $filename = shift;
    defined $filename
      or croak 'Usage: Conform::Core::IO::HTTP::file_uncomment($filename, $cmd, @regex)';
    return file_uncomment_spec( $filename, '#', @_ );
}

=item B<template_install>

    $updated = template_install $filename, $template, \%data, $cmd, \%flags;

A generic template method, which uses Text::Template for interpolation.

I<$filename> is the destination file to install the generated template to.  The generated template
is passed to L<text_install>, so I<%flags> and I<$cmd> also apply to text_install.
I<%data> is used to fill in the template. See L<Text::Template> for info on interpolation.

C<$template> can be either one of the following:

=over

=item I<SCALAR>

    If I<$template> is a SCALAR it is treated as a 'string' to be interpolated, B<UNLESS> it resolves to a valid path on the file system,
    In which case it will use C<$template> as filename to pass to Text::Template::new.

=item I<SCALAR> ref

    If C<$template> is a SCALAR ref, it is treated as a 'string'.

=item I<ARRAY> ref

    If C<$template> is an ARRAY ref, it is treated as an Array of strings, which will be concatenated together and interpolated.

=item I<CODE> ref

    If <$template> is a CODE ref, it will be called and is expected to return the 'TYPE' and 'SOURCE' parameters to pass to the
    Text::Template constuctor. E.g.

        $template = sub { return ( 'TYPE' => 'STRING', SOURCE => 'My template' ) };

    See L<Text::Template> for valid 'TYPE' values.

=back

Flags that are prefixed with I<template_> will be passed as args to the the Text::Template constructor and stripped of the
'template_' prefix. E.g.

    I<template_source>, will be passed to OIE::Text::Template<gt>new as I<source>.

This gives more control over Text::Template.

B<NB> I<template_install> will die if it has any problems processing the template.

=cut

sub template_install {
    my ( $filename, $template, $data, $cmd, $flags ) = @_;

    $data  ||= {};
    $flags ||= {};

    $filename
      and defined $template
      and ref $data  eq 'HASH'
      and ref $flags eq 'HASH'
      or croak
'Usage: template_install($filename, $template, \%data, $cmd, \%flags)';

    my %tt_args = ();
    my $tt;

    for ( grep /^template_/, keys %$flags ) {
        my ($arg) = $_ =~ m/^template_(\w+)$/;
        $tt_args{$arg} = delete $flags->{$_};
    }

    unless ( $tt_args{TYPE} || $tt_args{type} ) {
      TYPE: for ( ( ref $template ) || '' ) {
            /^CODE$/ and do {
                @tt_args{qw(type source)} = $template->();
                last TYPE;
            };

            /^GLOB$/ and do {
                @tt_args{qw(type source)} = ( 'FILEHANDLE', $template );
                last TYPE;
            };

            /^SCALAR$/ and do {
                @tt_args{qw(type source)} = ( 'STRING', $$template );
                last TYPE;
            };

            /^ARRAY$/ and do {

            # Array of strings is supported by Text::Template for some reason :)
                @tt_args{qw(type source)} = ( 'ARRAY', $template );
                last TYPE;
            };

            /^$/ and do {

                no warnings;

                # If this is a string 'stat' warns on non-printable characters
                local $^W;
                @tt_args{qw(type source)} =
                  -f $template
                  ? ( 'FILE', $template )
                  : ( 'STRING', $template );
                last TYPE;
            };
        }
    }

    $tt_args{source} = $template
      unless exists $tt_args{source};

    # normalise (Text::Template uses upper case args)
    for ( grep /^[a-z]+$/, keys %tt_args ) {
        if ( exists $tt_args{ uc $_ } ) {

            # Upper case args take precedence
            delete $tt_args{$_};
        }
        else {
            $tt_args{ uc $_ } = delete $tt_args{$_};
        }
    }

    $tt = Text::Template->new(%tt_args);

    my $error = '';

    my $text = $tt->fill_in(
        HASH   => $data,
        BROKEN => sub {
            my %args = @_;
            die "template error line $args{lineno}: $args{error}";
            return;
        },
        BROKEN_ARG => \$error
    );
    unless ( defined $text ) {
        die $Text::Template::ERROR;
    }

    return text_install $filename, $text, $cmd, $flags;

}

=item B<template_text_install>

    $updated = template_text_install $filename, $template_text, \%data, $cmd, \%flags;

A convenience method to install a 'text' template. See L<template_install>

=cut

sub template_text_install {
    my ( $filename, $template, $data, $cmd, $flags ) = @_;

    $data  ||= {};
    $flags ||= {};

    $filename and $template and ref $data eq 'HASH' and ref $flags eq 'HASH'
      or croak
'Usage: template_text_install($filename, $template_text, \%data, $cmd, \%flags)';

    return template_install $filename, $template, $data, $cmd,
      { template_type => 'STRING', %$flags };
}

=item B<template_file_install>

    $updated = template_file_install $filename, $template_file, \%data, $cmd, \%flags;

A convenience method to install a 'file' template. See L<template_install>

=cut

sub template_file_install {
    my ( $filename, $template, $data, $cmd, $flags ) = @_;

    $data  ||= {};
    $flags ||= {};

    $filename and $template and ref $data and ref $data eq 'HASH'
      or croak
'Usage: template_text_install($filename, $template_text, \%data, $cmd, \%flags)';

    die "Template file not found or not readable: $template"
      unless -r $template;

    return template_install $filename, $template, $data, $cmd,
      { template_type => 'FILE', %$flags };
}

=item B<dir_check>

    $updated = dir_check $dirname, \%flags;

If safe mode is not enabled, ensures that the specified directory exists. If it
needed to be created or its permissions were updated, returns true.

Note that the current umask is I<not> applied when the directory is created.

An optional flags hashref may be supplied as the last argument. The following
flags are recognized:

=over

=item I<mode>, I<owner> or I<uid>, I<group> or I<gid>, I<quiet>

Passed to B<set_attr> (see above) when setting the attributes of the directory.

=back

=cut

sub dir_check {

    my $dirname = shift;
    # directory name must contain valid value, at least a non-whitespace
    defined $dirname and $dirname =~ m/\S+/
      or croak 'Usage: Conform::Core::IO::HTTP::dir_check($dirname, $cmd, \%flags)';

    my $cmd;
    my $flags;

    # Compatibility...
    if ( @_ and ref $_[0] ) {
        $flags = shift;
    }
    else {
        $cmd = shift;

        # once upon a time, the second option set the mode
        die "Please use \%flags to set mode with dir_check\n"
          if ( $cmd and $cmd =~ m/^\d+$/ );

        $flags = shift;
        $flags ||= {};
    }

    my $changed = 0;
    if ( -e $dirname ) {
        -d _ or die "$dirname is not a directory\n";
    }
    else {

        # make parent if required
        ( my $parent = $dirname ) =~ s!/[^/]+/?$!!;
        dir_check $parent, $flags
          if $parent
              and $parent ne $dirname
              and not -e $parent;

        my $mode = $flags->{mode} || 0755;
        my $omode = sprintf '%03o', $mode;
        $changed +=
          action "Creating directory $dirname with mode $omode" => sub {
            my $mask = umask 0;
            mkdir $dirname, $mode
              or die "Could not create directory $dirname: $!\n";
            umask $mask;
            1;
          };
    }

    $changed += set_attr $dirname, $flags;
    if ( $changed and defined $cmd ) {
        command $cmd, { note => "Running '$cmd' to finish check of $dirname" };
    }

    return $changed

}

=item B<dir_install>

    $updated = dir_install $dirname, $source, $cmd, \%flags, @expr;

If safe mode is not enabled, recursively installs an entire directory tree of
files. If any files were updated, the command C<$cmd> is executed and a true
value is returned.

If the flags hashref is specified, the following flags are recognized:

=over

=item I<filter>

A coderef taking three parameters: the destination directory, the source
directory, and a file that is about to be processed. If the coderef returns a
true value then the file will be installed to the destination; otherwise the
file is skipped.

=back

If C<@expr> is provided, it is passed along to B<file_install> as the list of
transformations to apply to each file.

=cut

sub dir_install_http;
sub dir_install;

sub dir_install {
    my ( $dirname, $source, $cmd, $flags, @expr ) = @_;
    defined $dirname and defined $source
      or croak
'Usage: Conform::Core::IO::HTTP::dir_check($dirname, $source, $cmd, \%flags, @expr)';

    my $filter;
    $filter = $flags->{'filter'}
      if $flags
          and $flags->{'filter'}
          and ref $flags->{'filter'} eq 'CODE';

    my $changed = 0;

    my $sdir = IO::Dir->new($source)
      or die "Could not opendir '$source': $!\n";
    while ( defined( local $_ = $sdir->read ) ) {
        next if /^\.\.?$/;
        if ( not defined $filter or $filter->( $dirname, $source, $_ ) ) {
            if ( -d "$source/$_" ) {
                $changed += dir_install("$dirname/$_", "$source/$_", undef,
                  $flags, @expr)
                  unless /^(CV|RC)S$/;
            }
            else {
                $changed += file_install("$dirname/$_", "$source/$_", undef,
                  $flags, @expr);
            }
        }
    }

    if ( $changed and defined $cmd ) {
        command $cmd,
          { note => "Running '$cmd' to finish install of $dirname" };
    }

    return $changed
}

=item B<dir_install_http>

    $updated = dir_install_http $dirname, $uri, $cmd, \%flags, @expr;

If safe mode is not enabled, recursively installs an entire directory tree of
files from either the file system or from a URI. If any files were updated, the command C<$cmd> is executed and a true
value is returned.

If the flags hashref is specified, the following flags are recognized:

=over

=item I<filter>

A coderef taking three parameters: the destination directory, the source
directory, and a file that is about to be processed. If the coderef returns a
true value then the file will be installed to the destination; otherwise the
file is skipped.

=back

If C<@expr> is provided, it is passed along to B<file_install> as the list of
transformations to apply to each file.

=cut

sub dir_install_http;

sub dir_install_http {
    my ( $dirname, $source, $cmd, $flags, @expr ) = @_;

    defined $dirname and defined $source
      or croak
'Usage: Conform::Core::IO::HTTP::dir_install_http ($dirname, $source, [$cmd, \%flags, @expr])';

    my $filter;
    $filter = $flags->{'filter'}
      if $flags
          and $flags->{'filter'}
          and ref $flags->{'filter'} eq 'CODE';

    my $changed = 0;
    $changed += dir_check $dirname, $flags;

    my $uri = $source;
    $uri = "$uri/"
      unless $uri =~ m{/$};

    my @files = dir_list_http $uri, $flags;
  FILE: for (@files) {
        if ( not defined $filter or $filter->( $dirname, $source, $_ ) ) {
            s/\/$// and do {
                debug "dir_install_http recursively retrieving $source/$_";
                $changed += dir_install_http "$dirname/$_", "$source/$_", undef,
                  $flags, @expr
                  unless /^(CV|RC)S$/;
                next FILE;
            };

            $changed +=
              http_install( "$dirname/$_", "$source/$_", undef, $flags, @expr );
            die "$@" if $@;
        }
    }

    command $cmd, { note => "Running '$cmd' to finish install of $dirname" }
      if $cmd && $changed;

    return $changed;
}

=item B<symlink_check>

    $updated = symlink_check $target, $symlink, \%flags;

If safe mode is not enabled, ensures the symlink C<$symlink> points to the
existing file C<$target>. (Mnemonic: this is the same argument order as C<ln
-s>.) If the symlink was created or its target was updated, a true value is
returned.

An optional flags hashref may be supplied as the last argument.  Only one
value is recognised: I<force>, which has a value of true or false.

Dies if C<$symlink> exists and is I<not> already a symlink unless
C<$flags->{force}> has a true value. If C<$flags->{force}> is true,
then if the pathname C<$symlink> is an ordinary file, it will be
overwritten with the symlink, as with $<ln -sf>.

=cut

sub symlink_check {
    my ( $target, $symlink, $flags ) = @_;
    $flags ||= {};

    defined $target and defined $symlink and ref $flags eq 'HASH'
      or croak 'Usage: Conform::Core::IO::HTTP::symlink_check($target, $symlink, \%flags)';

    my $action;

    if ( -l $symlink ) {
        return 0 if ( readlink $symlink ) eq $target;
        $action = "Changing target of symlink $symlink to $target";
    }
    elsif ( $flags->{force} and -e _ ) {
        $action = "OVERWRITING ordinary file $symlink with symlink "
          . "$symlink to $target";
    }
    elsif ( -e _ ) {
        die "$symlink is not a symlink\n";
    }
    else {
        action "Creating symlink $symlink to $target" => sub {
            symlink $target, $symlink
              or die "Could not symlink $symlink to $target: $!\n";
        };
    }
    if ($action) {
        action $action => sub {
            unlink $symlink
              or die "Could not unlink $symlink: $!\n";
            symlink $target, $symlink
              or die "Could not symlink $symlink to $target: $!\n";
        };
    }

    return 1;
}

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

=item B<this_tty>

  $tty = this_tty;

Tries really really hard to guesstimate the local tty, then return it.

=cut

sub this_tty
{

    my $tty;

    #The command we are going to run is read only, non change making command.
    #Store the safe value away and then set it to 0 so that the command will run.

    debug 'Suspending safe mode while determining the TTY' if $safe_mode;
    local $safe_mode = 0;

    command( "ps -o tty= $$", # this has ps look at our PID ($$) and return our tty (without column headers), its fishlogin proof!
        {
         success => 'Determined tty',
         failure => 'Failure when attempting to determine local tty',
         capture => \$tty,
        }  );

    chomp $tty;
    $tty =~ s{^/dev/}{};
    $tty ||= 'unknown';

    return $tty

}

=item B<x509_cert>

    $updated = x509_cert $cert, $key, \%attr;

If safe mode is not enabled, generate a X.509 certificate and key. If the
certificate or key changed, a true value is returned.

The optional attribute hashref can be used to override attributes of
the certificate:

=over

=item I<C>

Country (default: "AU")

=item I<ST>

State (default: "New South Wales")

=item I<L>

Location (default: "Sydney")

=item I<O>

Organization (default: "Optus Administration Pty Limited")

=item I<OU>

Organizational unit (default: "Optus Internet")

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
      or croak 'Usage: Conform::Core::IO::HTTP::x509_cert($cert, $key, \%attr)';

    $attr->{C}        ||= 'AU';
    $attr->{ST}       ||= 'New South Wales';
    $attr->{L}        ||= 'Sydney';
    $attr->{O}        ||= 'Optus Administration Pty Limited';
    $attr->{OU}       ||= 'Optus Internet';
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

=head1 DEPRECATED FUNCTIONS

=over

=item B<warning>, B<scream>

    warning @messages;
    scream  @messages;

Equivalent to:

    warn @messages;

and:

    die  @messages;

respectively.

=cut

sub warning {
    _deprecated warning =>
      "Conform::Core::IO::HTTP::warning is deprecated; use warn instead";
    carp @_;
    ();
}

sub scream {
    _deprecated scream => "Conform::Core::IO::HTTP::scream is deprecated; use die instead";
    croak @_;
}

=item B<file_install_http>

    $updated = file_install_http $uri, $filename;

Equivalent to:

    $updated = http_install $filename, $uri;

Note that the order of arguments is reversed.

=cut

sub file_install_http {
    my ( $uri, $file ) = @_;

    _deprecated
      file_install_http =>
      "Conform::Core::IO::HTTP::file_install_http(\$uri, \$filename) is deprecated;\n",
      "use Conform::Core::IO::HTTP::http_install(\$filename, \$uri, ...) instead\n",
      "(note the order of arguments)\n";

    return http_install $file, $uri;
}

=item B<inetd_service>

    inetd_service @args;

This function has been removed.

=cut

sub inetd_service {
    _deprecated inetd_service => 'Conform::Core::IO::HTTP::inetd_service is deprecated';
    croak 'Conform::Core::IO::HTTP::inetd_service: No replacement function available';
}

=back

=cut

1;

=head1 SEE ALSO

L<conform>

=head1 ID

    $Id: Utils.pm,v 1.127 2012/11/23 04:38:22 rodrigo Exp $

=cut
