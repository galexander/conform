package Conform::Action::IO;
use Mouse;
use Conform::Debug qw(Trace Debug);
use Data::Dump qw(dump);

use Conform::Action::Plugin;

use Conform::Core::IO qw(:all);
use Carp qw(croak);

our $VERSION = $Conform::VERSION;

sub check_queue_cmd {
    my $cmd = shift;
    my $attr = shift;
    if (defined $cmd and $cmd =~ /^Q:(.*)/) {
        Action 'Queue_command' => { '-cmd' => $1, -attr => $attr };
        return undef;
    }
    return $cmd;
}

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

    if ($updated && check_queue_cmd ($cmd)) {
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

    file_touch $file, check_queue_cmd($cmd), $attr;

}

sub File_install
    : Action {
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

    file_install $dest, $src, check_queue_cmd($cmd), $attr;
}

sub Text_install 
    : Action {
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

    text_install $dest, $text, check_queue_cmd($cmd), $attr;

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

    file_append $file, $line, $regex, check_queue_cmd($cmd), $create, $attr;
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

    file_modify $file, check_queue_cmd($cmd), $expr, $attr;
}

sub File_unlink
    : Action {
    Debug "File_unlink(%s)", dump($_[0]);

    my $args = shift;

    $args = named_args $args, [ "-file" => undef, "-cmd" => undef, ];

    my ($file, $cmd) = @{$args}{qw(-file -cmd)};
    $file or croak
"Usage: File_unlink { -file => 'file', -cmd => 'cmd' }";

    file_unlink $file, check_queue_cmd($cmd);
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

    file_comment_spec $file, $comment, check_queue_cmd($cmd), $regex;
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

sub Template_text_install
    : Action {
    Debug "Template_text_install(%s)", dump($_[0]);
    
    my $args = shift;

    $args = named_args $args, [ "-file" => undef,
                                "-template" => undef,
                                "-data" => {},
                                "-cmd"  => undef,
                                "-attr" => {}
                              ];

    my ($file, $template, $data, $cmd, $attr) =
            @{$args}{qw(-file -template -data -cmd -attr)};

    $file && defined $template or croak <<EOUSAGE;
Usage: Template_text_install {
            '-file'     => 'file',
            '-template' => 'template',
            '-data'     => {},
            '-cmd'      => 'cmd',
            '-attr'     => {}
       }
EOUSAGE

    template_text_install $file, $template, $data, check_queue_cmd($cmd), $attr;
}

sub Template_file_install
    : Action {
    Debug "Template_file_install(%s)", dump($_[0]);
    
    my $args = shift;

    $args = named_args $args, [ "-file" => undef,
                                "-template" => undef,
                                "-data" => {},
                                "-cmd"  => undef,
                                "-attr" => {}
                              ];

    my ($file, $template, $data, $cmd, $attr) =
            @{$args}{qw(-file -template -data -cmd -attr)};

    $file && $template or croak <<EOUSAGE;
Usage: Template_file_install {
            '-file'     => 'file',
            '-template' => 'template',
            '-data'     => {},
            '-cmd'      => 'cmd',
            '-attr'     => {}
       }
EOUSAGE

    template_file_install $file, $template, $data, check_queue_cmd($cmd), $attr;
}


sub Dir_install
        : Action {
    Debug "Dir_install(%s)", dump($_[0]);

    my $args = shift;

    $args = named_args $args,
                       [ "-dir" => undef,
                         "-src" => undef,
                         "-cmd" => undef,
                         "-attr" => { },
                       ];

    my ($dir, $src, $cmd, $attr) = @{$args}{qw(-dir -src -cmd -attr)};

    unless ($dir && defined $src) {
        croak "usage: Dir_install { -dir => 'path', -src => 'path' }";
    }

    dir_install $dir, $src, check_queue_cmd($cmd), $attr;

}

sub Dir_check
        : Action {
    Debug "Dir_check(%s)", dump($_[0]);

    my $args = shift;

    $args = named_args $args,
                       [ "-dir" => undef,
                         "-cmd" => undef,
                         "-attr" => { },
                       ];

    my ($dir, $cmd, $attr) = @{$args}{qw(-dir -cmd -attr)};

    $dir or
        croak "usage: Dir_check { -dir => 'path', -cmd => 'cmd', '-attr' => {} }";

    dir_check $dir, check_queue_cmd($cmd), $attr;
}

sub Symlink
    : Action {
    Debug "Symlink(%s)", dump($_[0]);
    
    my $args = shift;
    
    $args = named_args $args,
                       [ "-target" => undef,
                         "-link"   => undef,
                         "-cmd"    => undef,
                       ];

    my ($target, $link, $cmd)
        = @{$args}{qw(-target -link -cmd)};

    defined $target && defined $link or croak
"Usage: Symlink { -target => 'target',  -link => 'link', -cmd =>  'cmd', }";

    symlink_check $target, $link, check_queue_cmd($cmd);
}

sub Command 
    : Action {
    Debug "Command(%s)", dump($_[0]);
    
    my $args = shift;

    $args = named_args $args,
                       [ "-cmd"  => undef,
                         "-attr" => {}
                       ];


    my ($cmd, $attr) = @{$args}{qw(-cmd -attr)};

    $cmd or croak "usage: Command 'command'";

    if (check_queue_cmd($cmd, $attr)) {
        command $cmd, $attr || {};
    }
}

{
    my %run = ();

    sub Queue_command
        : Action {
        Debug "Queue_command(%s)", dump($_[0]);

        my $args = shift;
    
        $args = named_args $args,
                            [ '-cmd'  => undef,
                              '-attr' => undef,
                            ];
          
        my ($cmd, $attr) = @{$args}{qw(-cmd -attr)}; 

        $cmd or croak "usage: Queue_command 'cmd'";

        if($run{$cmd}++) {
            Debug "command $cmd already run";
            return 1;
        }
        
        command $cmd, $attr || {};
    }
    
}


1;
