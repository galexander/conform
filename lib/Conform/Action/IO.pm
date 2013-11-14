package Conform::Action::IO;
use Moose;
use Data::Dump qw(dump);

use Conform::Action::Plugin;

use Conform::Core::IO qw(:all);
use Carp qw(croak);
use Conform::Logger qw($log trace debug note notice warn fatal);

our $VERSION = $Conform::VERSION;

sub _execute(&@) {
    my $code = shift;
    my $cmd  = shift;
    my $attr = shift;

    my $result;

    if ($result = $code->()) {
        if (defined $cmd and $cmd =~ /^Q:(.*)/) {
            debug "Scheduling action $cmd";
            Action 'QCmd' => { 'cmd' => $1, attr => $attr };
        } elsif (defined $cmd) {
            note "Running $cmd\n";
            command $cmd;
        }
    }

    return $result;
}

sub File_attr
    : Action
    : Args(+file, cmd, +%attr)
    : Desc(Modify file attributes) {
    debug "File_attr(%s)", dump($_[0]);
    
    my $args = shift;
    
    my ($file, $cmd, $attr) = @{$args}{qw(file cmd attr)};
    $file or croak
"usage: File_attr { file => 'file', cmd => 'cmd', attr => { } }";

    _execute { set_attr $file, $attr } $cmd;
}

sub File_touch
    : Action
    : Args(+file, cmd, %attr) {
    debug "File_touch(%s)", dump($_[0]);

    my $args = shift;

    my ($file, $cmd, $attr) = @{$args}{qw(file cmd attr)};
    $file or croak
"usage: File_touch { file => 'file', cmd => 'cmd', attr => { } }";

    _execute { file_touch $file, undef, $attr } $cmd;
}

sub File_install
    : Action
    : Args(+file, +src, cmd, %attr) {
    debug "File_install(%s)", dump($_[0]);
    my $args = shift;

    my ($file, $src, $cmd, $attr) = @{$args}{qw(file src cmd attr)};

    unless ($file && $src) {
        croak 
"usage: File_install { file => 'file', src => 'src', cmd => 'cmd', attr => \\\%attr }";
    }

    _execute  { file_install $file, $src, undef, $attr } $cmd;
}

sub Text_install 
    : Action
    : Args(+file, +text, cmd, %attr) {
    debug "Text_install(%s)", dump($_[0]);

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

    _execute { text_install $file, $text, undef, $attr } $cmd;

}

sub File_append
    : Action
    : Args(+file, +line, +regex, cmd,  create) {
    debug "File_append(%s)", dump($_[0]);

    my $args = shift;

    my ($file, $line, $regex, $cmd, $create)
            = @{$args}{qw(file line regex cmd create)};

    $file && $line  or croak <<EOUSAGE;
usage: File_append { 
        file => 'file',
        line => 'line',
        regex' => 'regex',
        cmd => 'cmd', 
        create = 'create'
}
EOUSAGE

    _execute { file_append $file, $line, $regex, undef, $create } $cmd;
}


sub File_modify
    : Action
    : Args(+file, cmd) {
#    : Args(+file, cmd, +@expr) {
    debug "File_modify(%s)", dump($_[0]);

    my $args = shift;

    my ($file, $cmd, $expr)
            = @{$args}{qw(file cmd expr)};

    $file or croak <<EOUSAGE;
usage: File_modify { 
        file => 'file',
        cmd => 'cmd', 
        expr => []
}

EOUSAGE

    _execute { file_modify $file, undef, @$expr } $cmd
}

sub File_unlink
    : Action
    : Args(+file, cmd) {
    debug "File_unlink(%s)", dump($_[0]);

    my $args = shift;

    my ($file, $cmd) = @{$args}{qw(file cmd)};
    $file or croak
"usage: File_unlink { file => 'file', cmd => 'cmd' }";

    _execute { file_unlink $file } $cmd;
}

sub File_comment
    : Action
    : Args(+file, comment, cmd, regex) {
    debug "File_comment(%s)", dump($_[0]);

    my $args = shift;
    my ($file, $comment, $cmd, $regex) = @{$args}{qw(file comment cmd regex)};
    $file or croak
"usage: File_comment { file => 'file', comment => 'comment', cmd => 'cmd' }";

    $comment ||= "#";

    _execute { file_comment_spec $file, $comment, undef, $regex } $cmd;
}

sub File_uncomment
    : Action
    : Args(+file, command, cmd, regex) {
    debug "File_uncomment(%s)", dump($_[0]);

    my $args = shift;

    my ($file, $comment, $cmd, $regex) = @{$args}{qw(file comment cmd regex)};
    $file or croak
"usage: File_uncomment { file => 'file', comment => 'comment', cmd => 'cmd' }";

    $comment ||= "#";

    _execute { file_uncomment_spec $file, $comment, undef, $regex } $cmd;
}

sub Template_text_install
    : Action
    : Args(+file, +text, %data, cmd, %attr) {
    debug "Template_text_install(%s)", dump($_[0]);
    
    my $args = shift;

    my ($file, $text, $data, $cmd, $attr) =
            @{$args}{qw(file text data cmd attr)};

    $file && defined $text or croak <<EOUSAGE;
usage: Template_text_install {
            'file'     => 'file',
            'text'     => 'text',
            'data'     => {},
            'cmd'      => 'cmd',
            'attr'     => {}
       }
EOUSAGE

    _execute { template_text_install $file, $text, $data, undef, $attr } $cmd;
}

sub Template_file_install
    : Action
    : Args(+file, +template, %data, cmd, %att) {
    debug "Template_file_install(%s)", dump($_[0]);
    
    my $args = shift;

    my ($file, $template, $data, $cmd, $attr) =
            @{$args}{qw(file template data cmd attr)};

    $file && $template or croak <<EOUSAGE;
usage: Template_file_install {
            'file'     => 'file',
            'template' => 'template',
            'data'     => {},
            'cmd'      => 'cmd',
            'attr'     => {}
       }
EOUSAGE

    _execute { template_file_install $file, $template, $data, undef, $attr  } $cmd;
}


sub Dir_install
        : Action
        : Args(+dir, +src, cmd, %attr) {
    debug "Dir_install(%s)", dump($_[0]);

    my $args = shift;

    my ($dir, $src, $cmd, $attr) = @{$args}{qw(dir src cmd attr)};

    unless ($dir && defined $src) {
        croak 
"usage: Dir_install { dir => 'path', src => 'path' }";
    }

    _execute { dir_install $dir, $src, undef, $attr } $cmd;

}

sub Dir_check
        : Action
        : Args(+dir, cmd, %attr) {
    debug "Dir_check(%s)", dump($_[0]);

    my $args = shift;

    my ($dir, $cmd, $attr) = @{$args}{qw(dir cmd attr)};

    $dir or
        croak "usage: Dir_check { dir => 'path', cmd => 'cmd', 'attr' => {} }";

    _execute { dir_check $dir, undef, $attr } $cmd;
}

sub Symlink
    : Action
    : Args(+target, +link, cmd) {
    debug "Symlink(%s)", dump($_[0]);
    
    my $args = shift;
    
    my ($target, $link, $cmd)
        = @{$args}{qw(target link cmd)};

    defined $target && defined $link or croak
"usage: Symlink { target => 'target',  link => 'link', cmd =>  'cmd', }";

    _execute { symlink_check $target, $link, undef } $cmd;
}

sub Links
    : Action(links)
    : Args(+target, +link, cmd) {
    debug "Links(%s)", dump($_[0]);
    
    my $args = shift;
    
    my ($link, $target, $cmd)
        = @{$args}{qw(target link cmd)};

    defined $target && defined $link or croak
"usage: Links { target => 'target',  link => 'link', cmd =>  'cmd', }";

    _execute { symlink_check $target, $link, undef } $cmd;
}


sub Command 
    : Action
    : Args(+cmd, %attr) {
    debug "Command(%s)", dump($_[0]);
    
    my $args = shift;

    my ($cmd, $attr) = @{$args}{qw(cmd attr)};

    $cmd or croak "usage: Command 'command'";

    _execute { 1; } $cmd;
}

{
    my %run = ();

    sub QCmd
        : Action
        : Args(+cmd, %attr) {
        debug "QCmd(%s)", dump($_[0]);

        my $args = shift;
    
        my ($cmd, $attr) = @{$args}{qw(cmd attr)}; 

        $cmd or croak "usage: Qcmd 'cmd'";

        if($run{$cmd}++) {
            debug "command $cmd already run";
            return 1;
        }
        
        note "running $cmd\n";
        command $cmd, $attr || {};
    }
    
}


1;
