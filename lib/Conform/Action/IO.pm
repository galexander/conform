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
    : Action
    : Args(+file, cmd, +%attr)
    : Desc(Modify file attributes) {
    Debug "File_attr(%s)", dump($_[0]);
    
    my $args = shift;
    
    my ($file, $cmd, $attr) = @{$args}{qw(file cmd attr)};
    $file or croak
"Usage: File_attr { file => 'file', cmd => 'cmd', attr => { } }";

    my $updated = set_attr $file, $attr;

    if ($updated && check_queue_cmd ($cmd)) {
        command $cmd;
    }

    $updated;
}

sub File_touch
    : Action
    : Args(+file, cmd, %attr) {
    Debug "File_touch(%s)", dump($_[0]);

    my $args = shift;

    my ($file, $cmd, $attr) = @{$args}{qw(file cmd attr)};
    $file or croak
"Usage: File_touch { file => 'file', cmd => 'cmd', attr => { } }";

    file_touch $file, check_queue_cmd($cmd), $attr;

}

sub File_install
    : Action
    : Args(+file, +src, cmd, %attr) {
    Debug "File_install(%s)", dump($_[0]);
    my $args = shift;

    my ($file, $src, $cmd, $attr) = @{$args}{qw(file src cmd attr)};

    unless ($file && $src) {
        croak "usage: File_install { file => 'file', src => 'src', cmd => 'cmd', attr => \\\%attr }";
    }

    file_install $file, $src, check_queue_cmd($cmd), $attr;
}

sub Text_install 
    : Action
    : Args(+file, +text, cmd, %attr) {
    Debug "Text_install(%s)", dump($_[0]);

    my $args = shift;

    my ($file, $text, $cmd, $attr) = @{$args}{qw(file text cmd attr)};

    unless ($file && defined $text) {
        croak <<EOUSAGE;
usage: Text_install { 
            file => 'file',
            text => 'text',
            cmd  => 'cmd',
            attr => \%attr
EOUSAGE
           
    }

    text_install $file, $text, check_queue_cmd($cmd), $attr;

}

sub File_append
    : Action
    : Args(+file, +line, +regex, cmd,  create, %attr) {
    Debug "File_append(%s)", dump($_[0]);

    my $args = shift;

    my ($file, $line, $regex, $cmd, $create, $attr)
            = @{$args}{qw(file line regex cmd create attr)};

    $file && $line  or croak <<EOUSAGE;
Usage: File_append { 
        file => 'file',
        line => 'line',
        regex' => 'regex',
        cmd => 'cmd', 
        create = 'create',
        attr => { }
}
EOUSAGE

    file_append $file, $line, $regex, check_queue_cmd($cmd), $create, $attr;
}


sub File_modify
    : Action
    : Args(+file, +@expr, cmd, %attr) {
    Debug "File_modify(%s)", dump($_[0]);

    my $args = shift;

    my ($file, $cmd, $expr, $attr)
            = @{$args}{qw(file expr cmd attr)};

    $file or croak <<EOUSAGE;
Usage: File_modify { 
        file => 'file',
        cmd => 'cmd', 
        expr => [],
        attr => { }

EOUSAGE

    file_modify $file, check_queue_cmd($cmd), $expr, $attr;
}

sub File_unlink
    : Action
    : Args(+file, cmd) {
    Debug "File_unlink(%s)", dump($_[0]);

    my $args = shift;

    my ($file, $cmd) = @{$args}{qw(file cmd)};
    $file or croak
"Usage: File_unlink { file => 'file', cmd => 'cmd' }";

    file_unlink $file, check_queue_cmd($cmd);
}

sub File_comment
    : Action
    : Args(+file, comment, cmd, regex) {
    Debug "File_comment(%s)", dump($_[0]);

    my $args = shift;
    my ($file, $comment, $cmd, $regex) = @{$args}{qw(file comment cmd regex)};
    $file or croak
"Usage: File_comment { file => 'file', comment => 'comment', cmd => 'cmd' }";

    $comment ||= "#";

    file_comment_spec $file, $comment, check_queue_cmd($cmd), $regex;
}

sub File_uncomment
    : Action
    : Args(+file, command, cmd, regex) {
    Debug "File_uncomment(%s)", dump($_[0]);

    my $args = shift;

    my ($file, $comment, $cmd, $regex) = @{$args}{qw(file comment cmd regex)};
    $file or croak
"Usage: File_uncomment { x-file => 'file', x-comment => 'comment', cmd => 'cmd' }";

    $comment ||= "#";

    file_uncomment_spec $file, $comment, $cmd, $regex;
}

sub Template_text_install
    : Action
    : Args(+file, +text, %data, cmd, %attr) {
    Debug "Template_text_install(%s)", dump($_[0]);
    
    my $args = shift;

    my ($file, $text, $data, $cmd, $attr) =
            @{$args}{qw(file text data cmd attr)};

    $file && defined $text or croak <<EOUSAGE;
Usage: Template_text_install {
            'file'     => 'file',
            'text'     => 'text',
            'data'     => {},
            'cmd'      => 'cmd',
            'attr'     => {}
       }
EOUSAGE

    template_text_install $file, $text, $data, check_queue_cmd($cmd), $attr;
}

sub Template_file_install
    : Action
    : Args(+file, +template, %data, cmd, %att) {
    Debug "Template_file_install(%s)", dump($_[0]);
    
    my $args = shift;

    my ($file, $template, $data, $cmd, $attr) =
            @{$args}{qw(file template data cmd attr)};

    $file && $template or croak <<EOUSAGE;
Usage: Template_file_install {
            'file'     => 'file',
            'template' => 'template',
            'data'     => {},
            'cmd'      => 'cmd',
            'attr'     => {}
       }
EOUSAGE

    template_file_install $file, $template, $data, check_queue_cmd($cmd), $attr;
}


sub Dir_install
        : Action
        : Args(+dir, +src cmd %attr) {
    Debug "Dir_install(%s)", dump($_[0]);

    my $args = shift;

    my ($dir, $src, $cmd, $attr) = @{$args}{qw(dir src cmd attr)};

    unless ($dir && defined $src) {
        croak "usage: Dir_install { dir => 'path', src => 'path' }";
    }

    dir_install $dir, $src, check_queue_cmd($cmd), $attr;

}

sub Dir_check
        : Action
        : Args(+dir, cmd, %attr) {
    Debug "Dir_check(%s)", dump($_[0]);

    my $args = shift;

    my ($dir, $cmd, $attr) = @{$args}{qw(dir cmd attr)};

    $dir or
        croak "usage: Dir_check { dir => 'path', cmd => 'cmd', 'attr' => {} }";

    dir_check $dir, check_queue_cmd($cmd), $attr;
}

sub Symlink
    : Action
    : Args(+target, +link, cmd) {
    Debug "Symlink(%s)", dump($_[0]);
    
    my $args = shift;
    
    my ($target, $link, $cmd)
        = @{$args}{qw(target link cmd)};

    defined $target && defined $link or croak
"Usage: Symlink { target => 'target',  link => 'link', cmd =>  'cmd', }";

    symlink_check $target, $link, check_queue_cmd($cmd);
}

sub Command 
    : Action
    : Args(+cmd, %attr) {
    Debug "Command(%s)", dump($_[0]);
    
    my $args = shift;

    my ($cmd, $attr) = @{$args}{qw(cmd attr)};

    $cmd or croak "usage: Command 'command'";

    if (check_queue_cmd($cmd, $attr)) {
        print "Running $cmd\n";
        command $cmd, $attr;
    }
}

{
    my %run = ();

    sub Queue_command
        : Action
        : Args(+cmd, %attr) {
        Debug "Queue_command(%s)", dump($_[0]);

        my $args = shift;
    
        my ($cmd, $attr) = @{$args}{qw(cmd attr)}; 

        $cmd or croak "usage: Queue_command 'cmd'";

        if($run{$cmd}++) {
            Debug "command $cmd already run";
            return 1;
        }
        
        command $cmd, $attr || {};
    }
    
}


1;
