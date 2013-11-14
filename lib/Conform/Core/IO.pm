package Conform::Core::IO;
use strict;

=head1  NAME

Conform::Core::IO - Conform Core IO utility functions

=head1 SYNOPSIS

    use Conform::Core::IO qw(:all);

    $content = slurp_file $filename;
    @lines   = slurp_file $filename;

    $content = slurp_http $filename;
    @lines   = slurp_http  $filename;

    safe_write      $filename, @lines, \%flags;
    safe_write      $filename, \*FH,   \%flags;
    safe_write_file $filename, @lines, \%flags;
    safe_write_file $filename, \*FH,   \%flags;

    $updated  = set_attr $filename, \%flags;
    %attr     = get_attr $filename;
    %attr     = get_attr \*FH;

    $updated  = text_install $filename, $text,   $cmd, \%flags;
    $updated  = file_install $filename, $source, $cmd, \%flags, @expr;
    $updated  = file_install_http $filename, $source, $cmd, \%flags, @expr;

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

    $updated  = dir_check        $dirname, $cmd, \%flags;
    $updated  = dir_install      $dirname, $source, $cmd, \%flags;
    $updated  = dir_install_http $dirname, $source, $cmd, \%flags;

    $updated  = symlink_check $target, $symlink, \%flags;

    $tty  = this_tty;

=head1 DESCRIPTION

The Conform::Core::IO::File module contains a collection of useful file/dir/io
functions for Conform

=cut

use base 'Exporter';
our @EXPORT_OK = (qw(slurp_file
                     slurp_http
                     safe_write
                     safe_write_file
                     file_install
                     file_install_http
                     text_install
                     set_attr
                     get_attr
                     file_touch
                     file_append
                     file_modify
                     file_unlink
                     file_comment
                     file_comment_spec
                     file_uncomment
                     file_uncomment_spec
                     template_install
                     template_file_install
                     template_text_install
                     dir_check
                     dir_install
                     dir_install_http
                     dir_list
                     dir_list_http
                     symlink_check
                     this_tty
                     command)
);

our %EXPORT_TAGS = (
    'all' => [ @EXPORT_OK ]
);

use Conform::Core::IO::File (qw(safe_write
                                safe_write_file
                                text_install
                                set_attr
                                get_attr
                                file_append
                                file_touch
                                file_modify
                                file_unlink
                                file_comment
                                file_comment_spec
                                file_uncomment
                                file_uncomment_spec
                                template_install
                                template_text_install
                                dir_check
                                symlink_check
                                this_tty));

use Conform::Core::IO::HTTP (qw(slurp_http
                                file_install_http                                
                                dir_list_http
                                dir_install_http));

use Conform::Core::IO::Command qw(command);
                                

=head1  METHODS

=over

=item B<slurp_file>

    $content = slurp_file $filename;
    @lines   = slurp_file $filename;

Calls L<Conform::Core::IO::File::slurp_file> or L<Conform::Core::IO::HTTP::slurp_http>
if the filename begins with the string C<"https?://">.

=cut

sub slurp_file {
    my $filename = shift;
    return
        $filename =~ m{^https?://}
            ? Conform::Core::IO::HTTP::slurp_http ($filename, @_)
            : Conform::Core::IO::File::slurp_file ($filename, @_);
}

=item B<safe_write>, B<safe_write_file>

    safe_write      $filename, @lines, \%flags;
    safe_write      $filename, \*FH,   \%flags;
    safe_write_file $filename, @lines, \%flags;
    safe_write_file $filename, \*FH,   \%flags;


See L<Conform::Core::IO::File::safe_write>

=item B<set_attr>, B<get_attr>

    $updated = set_attr $filename, \%flags;
    %attr = get_attr $filename;
    %attr = get_attr \*FH;

See L<Conform::Core::IO::File::set_attr>, L<Conform::Core::IO::File::get_attr>

=item B<text_install>, B<file_install>, B<file_install_http>

    $updated = text_install $filename, $text,   $cmd, \%flags;
    $updated = file_install $filename, $source, $cmd, \%flags, @expr;
    $updated = file_install_http $filename, $uri,    $cmd, \%flags, @expr;

See L<Conform::Core::IO::File::text_install>, L<Conform::Core::IO::file_install>
    L<Conform::Core::IO::HTTP::file_install_http>

=cut

sub file_install {
    my $filename = shift;
    my $source   = shift;
    return $source =~ m{^https?://}
                ? return Conform::Core::IO::HTTP::file_install_http($filename, $source, @_)
                : return Conform::Core::IO::File::file_install($filename, $source, @_);
}

=item B<file_touch>, B<file_append>, B<file_modify>, B<file_comment> B<file_comment_spec>
      B<file_uncomment> B<file_uncomment_spec>

    $updated = file_append $filename, $line, $regex, $cmd, $create;

See
L<Conform::Core::IO::File::file_touch>,
L<Conform::Core::IO::File::file_modify>,
L<Conform::Core::IO::File::file_append>, 
L<Conform::Core::IO::File::file_modify>,
L<Conform::Core::IO::File::file_comment>,
L<Conform::Core::IO::File::file_comment_spec>,
L<Conform::Core::IO::File::file_uncomment>,
L<Conform::Core::IO::File::file_uncomment_spec>

=item B<file_modify>

    $updated = file_append $filename, $line, $regex, $cmd, $create;
    $updated = file_modify $filename, $cmd, @expr;

    $updated = file_comment_spec $filename, $comment, $cmd, @regex;
    $updated = file_comment      $filename,           $cmd, @regex;

    $updated = file_comment_spec $filename, $comment, $cmd, @regex;
    $updated = file_comment      $filename,           $cmd, @regex;


=item B<template_install>, B<template_text_install>, B<template_file_install>

    $updated = template_install      $filename, $template, \%data, $cmd, \%flags;
    $updated = template_text_install $filename, $template_text, \%data, $cmd, \%flags;
    $updated = template_file_install $filename, $template_file, \%data, $cmd, \%flags;

=cut

sub template_file_install {
    my ($filename, $template_file) = @_;

    if ($template_file =~ m{^https?://}) {
        return template_text_install $filename,
                                     (scalar slurp_http $template_file),
                                     @_;
    } else {
        return template_file_install $filename, $template_file, @_;
    }
}

=item B<dir_list>, B<dir_list_http>

    @filenames = dir_list $path, \%flags;
    $filenames = dir_list $path, \%flags;

See 
L<Conform::Core::IO::File::dir_list>,
L<Conform::Core::IO::HTTP::dir_list_http>

=cut

sub dir_list {
    my $path = shift;
    return $path =~ m{^https?://}
                ? Conform::Core::IO::HTTP::dir_list_http ($path, @_)
                : Conforn::Core::IO::File::dir_list ($path, @_);
}


=item B<dir_check>

    $updated = dir_check $dirname, \%flags;

See L<Conform::Core::IO::File::dir_check>

=item B<dir_install>, B<dir_install_http>

    $updated = dir_install $dirname, $source, $cmd, \%flags, @expr;

See L<Conform::Core::IO::File::dir_install>, L<Conform::Core::IO::HTTP::dir_install_http>

=cut

sub dir_install {
    return $_[0] =~ m{^http://}
            ? Conform::Core::IO::HTTP::dir_install_http(@_)
            : Conform::Core::IO::File::dir_install(@_);
}

=item B<symlink_check>

    $updated = symlink_check $target, $symlink, \%flags;

See L<Conform::Core::IO::File::symlink_check>

=item B<this_tty>

  $tty = this_tty;

=cut

1;

=back

=head1 SEE ALSO


L<conform>,
L<Conform::Core::IO::File>,
L<Conform::Core::IO::HTTP>,
L<Conform::Core::IO::Command>

=cut

1;
