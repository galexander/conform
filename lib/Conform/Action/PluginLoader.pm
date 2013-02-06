package Conform::Action::PluginLoader;
use Mouse;
use Conform::Debug qw(Trace Debug);
use Data::Dump qw(dump);

with 'Conform::PluginLoader';

sub get_plugins {
    my $self = shift;

    Trace;

    my $finder = $self->plugin_finder;
    
    Debug "%s", dump($finder);

    for ($finder->plugins) {
        Debug "Found Potential Plugin Provider %s", $_;
        $self->plugin($_);
    }

    $self->plugins;
}


1;
# vi: set ts=4 sw=4:
# vi: set expandtab:
