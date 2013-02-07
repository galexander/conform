#!/usr/bin/perl
#!/bin/false

=encoding utf8

=head1 NAME

Conform::Core::IO::HTTP - Conform common http io functions

=head1 SYNOPSIS

    use Conform::Core::IO::HTTP qw(:all :deprecated :conformhandlers);

    $content = slurp_http $uri, \%flags;
    @lines   = slurp_http $uri, \%flags;

    $updated  = http_install $filename, $uri,    $cmd, \%flags, @expr;

    $filenames = dir_list_http $uri, \%flags;
    @filenames = dir_list_http $uri, \%flags;

    $updated  = dir_install_http $dirname, $source, $cmd, \%flags;

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
use Conform::Debug qw(Debug);
use Conform::Core qw(
                    debug
                    action
                    timeout
                    safe
                    $safe_mode
                    $debug
                    $safe_write_msg
                    );

use Conform::Core::IO::Command qw(command);
use Conform::Core::IO::File qw(safe_write safe_write_file dir_check);

use base qw( Exporter );
use vars qw(
  $VERSION %EXPORT_TAGS @EXPORT_OK
  $debug $safe_mode $safe_write_msg $log_messages $warnings
);
$VERSION     = (qw$Revision: 1.127 $)[1];
%EXPORT_TAGS = (
    all => [
        qw(
          slurp_http
          http_install
          dir_install_http
          dir_list_http
          )
    ],
    deprecated => [
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

my $intest = $ENV{'HARNESS_VERSION'} || $ENV{'HARNESS_ACTIVE'};

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

=head1 FUNCTIONS

=over

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

=back

=cut

1;

=head1 SEE ALSO

L<conform>

=cut
