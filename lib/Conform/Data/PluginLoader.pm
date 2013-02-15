package Conform::Data::PluginLoader;
use Mouse;

with 'Conform::PluginLoader';

sub register {

}

sub get_plugins {
    my $self = shift;
    my $finder = $self->plugin_finder;
    for ($finder->plugins) {
        $self->plugin($_);
    }
    $self->plugins;
}


1;
# vi: set ts=4 sw=4:
# vi: set expandtab:
