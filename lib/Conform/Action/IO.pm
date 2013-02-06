package Conform::Action::IO;
use Mouse;
use Conform::Debug qw(Trace Debug);
use Data::Dump qw(dump);

use Conform::Plugin;

use Conform::Core::IO::File qw();

sub File_install : Action {
    Debug "File_install(%s)", dump(\@_);
    my ($file, $args, $action, $agent, $runtime) = @_;

    Debug "File = $file, Args = %s", dump ($args);
    Debug "Self  = %s", dump($action);
    Debug "Agent = %s", dump($agent);
    Debug "Runtime = %s", dump($runtime);
    
}

sub Text_install : Action {
    Debug "Text_install(%s)", dump(\@_);
    my $file = shift;
    my $args = shift;

}

sub Dir_install : Action {
    my $dir  = shift;
    my $args = shift;

    Trace "Dir";
}

sub Command : Action {
    my $cmd  = shift;
    my $args = shift;

    Trace "Command";
}


1;
