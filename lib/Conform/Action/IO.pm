package Conform::Action::IO;
use Mouse;
use Conform::Debug qw(Trace Debug);
use Data::Dump qw(dump);

use Conform::Action::Plugin;

use Conform::Core::IO qw(:all);
use Carp qw(croak);

our $VERSION = $Conform::VERSION;

sub File_attr
    : Action {
    Debug "File_attr(%s)", dump($_[0]);
    
    my $args = shift;
    
    $args = named_args $args,
                       [ "-file" => undef,
                         "-attr" => {}
                       ];

    my ($file, $cmd, $attr) = @{$args}{qw(-file -cmd -attr)};
    $file or croak
"Usage: File_attr { -file => 'file', -cmd => 'cmd', -attr => { } }";

    my $updated = set_attr $file, $attr;

    if ($updated && $cmd) {
        command $cmd;
    }

    $updated;
}

sub File_touch
    : Action {
    Debug "File_touch(%s)", dump($_[0]);

    my $args = shift;

    $args = named_args $args,
                       [ "-file" => undef,
                         "-cmd"  => undef,
                         "-attr" => {},
                       ];

    my ($file, $cmd, $attr) = @{$args}{qw(-file -cmd -attr)};
    $file or croak
"Usage: File_touch { -file => 'file', -cmd => 'cmd', -attr => { } }";

    file_touch $file, $cmd, $attr;

}

sub File_install
    : Action
    : Desc('Install file to -dest from -src') {
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

sub File_append
    : Action {
    Debug "File_append(%s)", dump($_[0]);

    my $args = shift;

    $args = named_args $args,
                       [ "-file"   => undef,
                         "-line"   => undef,
                         "-regex"  => undef,
                         "-cmd"    => undef,
                         "-create" => undef,
                         "-attr" => {},
                       ];

    my ($file, $line, $regex, $cmd, $create, $attr)
            = @{$args}{qw(-file -line -regex -cmd -create -attr)};

    $file && $line  or croak <<EOUSAGE;
Usage: File_append { 
        -file => 'file',
        -line => 'line',
        -regex' => 'regex',
        -cmd => 'cmd', 
        -create = 'create',
        -attr => { }
}
EOUSAGE

    file_append $file, $line, $regex, $cmd, $create, $attr;
}


sub File_modify
    : Action {
    Debug "File_modify(%s)", dump($_[0]);

    my $args = shift;

    $args = named_args $args,
                       [ "-file"   => undef,
                         "-cmd"    => undef,
                         "-expr"   => [],
                         "-attr" => {},
                       ];

    my ($file, $cmd, $expr, $attr)
            = @{$args}{qw(-file -cmd -expr -attr)};

    $file or croak <<EOUSAGE;
Usage: File_modify { 
        -file => 'file',
        -cmd => 'cmd', 
        -expr => [],
        -attr => { }
}
EOUSAGE

    file_modify $file, $cmd, $expr, $attr;
}

sub File_unlink
    : Action {
    Debug "File_unlink(%s)", dump($_[0]);

    my $args = shift;

    $args = named_args $args, [ "-file" => undef, "-cmd" => undef, ];

    my ($file, $cmd) = @{$args}{qw(-file -cmd)};
    $file or croak
"Usage: File_unlink { -file => 'file', -cmd => 'cmd' }";

    file_unlink $file, $cmd;
}

sub File_comment
    : Action {
    Debug "File_comment(%s)", dump($_[0]);

    my $args = shift;

    $args = named_args $args, [ "-file" => undef,
                                "-comment" => undef,
                                "-cmd"  => undef,
                                "-regex" => []
                              ];

    my ($file, $comment, $cmd, $regex) = @{$args}{qw(-file -comment -cmd -regex)};
    $file or croak
"Usage: File_comment { -file => 'file', -comment => 'comment', -cmd => 'cmd' }";

    $comment ||= "#";

    file_comment_spec $file, $comment, $cmd, $regex;
}

sub File_uncomment
    : Action {
    Debug "File_uncomment(%s)", dump($_[0]);

    my $args = shift;

    $args = named_args $args, [ "-file" => undef,
                                "-comment" => undef,
                                "-cmd"  => undef,
                                "-regex" => []
                              ];

    my ($file, $comment, $cmd, $regex) = @{$args}{qw(-file -comment -cmd -regex)};
    $file or croak
"Usage: File_uncomment { -file => 'file', -comment => 'comment', -cmd => 'cmd' }";

    $comment ||= "#";

    file_uncomment_spec $file, $comment, $cmd, $regex;
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
