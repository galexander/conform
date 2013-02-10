package Conform::Action::IO;
use Mouse;
use Conform::Debug qw(Trace Debug);
use Data::Dump qw(dump);

use Conform::Action::Plugin;

use Conform::Core::IO::File qw(file_install text_install);
use Conform::Core::IO::Command qw(command);
use Carp qw(croak);

our $VERSION = $Conform::VERSION;

sub File_install
    : Action
    : Desc("Install file to -dest from -src") {
    Debug "File_install(%s)", dump($_[0]);
    my $args = shift;

    $args = named_args $args,
                       [ "-dest" => undef,
                         "-src" => undef,
                         "-cmd" => undef,
                         "-attr" => { },
                       ];

    my ($dest, $src, $cmd, $attr) = @{$args}{qw(-dest -src -cmd)};

    unless ($dest && $src) {
        croak "usage: File_install { -dest => 'path', -src => 'path' }";
    }

    file_install $dest, $src, $cmd, $attr;
}

sub Text_install 
    : Action
    : Desc("Install -text into -dest") {
    Debug "Text_install(%s)", dump($_[0]);

    my $args = shift;

    $args = named_args $args,
                       [ "-dest" => undef,
                         "-text" => undef,
                         "-cmd" => undef,
                         "-attr" => { },
                       ];

    my ($dest, $text, $cmd, $attr) = @{$args}{qw(-dest -text -cmd)};

    unless ($dest && defined $text) {
        croak "usage: Text_install { -text => 'text', -src => 'path' }";
    }

    text_install $dest, $text, $cmd, $attr;

}

sub Dir_install
        : Action
        : Desc("Install -dir from -src") {
    Debug "Dir_install(%s)", dump($_[0]);

    my $args = shift;

    $args = named_args $args,
                       [ "-dir" => undef,
                         "-src" => undef,
                         "-cmd" => undef,
                         "-attr" => { },
                       ];

    my ($dir, $src, $cmd, $attr) = @{$args}{qw(-dir -src -cmd)};

    unless ($dir && defined $src) {
        croak "usage: Dir_install { -dir => 'path', -src => 'path' }";
    }

    dir_install $dir, $src, $cmd, $attr;
}

sub Command 
    : Action
    : Desc("Run a command") {
    Debug "Command(%s)", dump($_[0]);
    
    my $args = shift;

    $args = named_args $args,
                       [ "-cmd"  => undef,
                         "-attr" => {}
                       ];


    my ($cmd, $attr) = @{$args}{qw(-cmd -attr)};

    $cmd or croak "usage: Command 'command'";

    command $cmd, $attr || {};
}


1;
