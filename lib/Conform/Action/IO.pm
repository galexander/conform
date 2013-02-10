package Conform::Action::IO;
use Mouse;
use Conform::Debug qw(Trace Debug);
use Data::Dump qw(dump);

use Conform::Action::Plugin;

use Conform::Core::IO::File qw(file_install text_install);
use Conform::Core::IO::Command qw(command);

our $VERSION = $Conform::VERSION;

sub File_install
    : Action
    : ID(src)
    : ARGS(STRUCT) {
    Debug "File_install(%s)", dump(\@_);
    my ($file, $args, $action, $agent, $runtime) = @_;

    Debug "File = @{[$file||'']}, Args = %s", dump ($args);
    Debug "Self  = %s", dump($action);
    Debug "Agent = %s", dump($agent);
    Debug "Runtime = %s", dump($runtime);

    file_install "$file", $args->{src}, $args->{cmd}, $args;

    Action 'File_install' => '/tmp/d' => { src => '/tmp/a' };

    print "Agent(Site) = ", dump($agent->site);
}

sub Text_install : Action {
    Debug "Text_install(%s)", dump(\@_);
    my ($args, $action, $agent, $runtime) = @_;

    my $text = $args->{text};
    my $dest = $args->{file};

    text_install $dest, $text, $args->{cmd};

}

sub Dir_install : Action {
    my $dir  = shift;
    my $args = shift;

    Trace "Dir";
}

sub Command 
    : Action(Command)
    : Alias(Cmd)
    : Depend($runtime.os=linux) {
    my $cmd  = shift;
    my $args = shift;

    Trace "Command";

    command $cmd;

    Action "Text_install" => { file => '/tmp/flubble', 'text' => "asdef" };
}


1;
