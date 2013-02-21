package Conform::Task::PluginLoader;
use Mouse;
use Conform::Debug qw(Trace Debug);
use Data::Dump qw(dump);

with 'Conform::PluginLoader';

sub register {
    my $self   = shift;
    Debug "Register %s", dump(\@_);
    my %args = @_;
    my ($agent, $plugin, $name, $id, $version, $impl, $attr)
        = @args{qw(agent plugin name id version impl attr)};

    $attr ||= [];
    

    Debug "$plugin, $name, $id, $version, $attr";

    Trace;

    my $object = 
        $plugin->new('agent'    => $agent,
                     'name'     => $name,
                     'id'       => $id,
                     'version'  => $version,
                     'impl'     => $impl);

    
    Debug "Object %s", dump($object);

    my $plugins = $self->plugins;
    $plugins ||= [];
    push @$plugins, $object;
    $self->plugins($plugins);
}

sub get_plugins {
    my $self = shift;

    Trace;

    my $finder = $self->plugin_finder(@_);
    
    Debug "%s", dump($finder);

    for ($finder->plugins) {
        Debug "Found potential plugin provider %s", $_;
        $self->plugin($_);
    }


    $self->plugins;
}


1;
# vi: set ts=4 sw=4:
# vi: set expandtab:
