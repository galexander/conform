package Conform::Task::PluginLoader;
use Moose;
use Data::Dump qw(dump);
use Conform::Logger qw($log debug trace warn notice fatal);

with 'Conform::PluginLoader';

sub register {
    my $self   = shift;
    debug "Register %s", dump(\@_);
    my %args = @_;
    my ($agent, $plugin, $name, $id, $version, $impl, $attr)
        = @args{qw(agent plugin name id version impl attr)};

    $attr ||= [];
    

    debug "$plugin, $name, $id, $version, $attr";

    trace;

    my $object = 
        $plugin->new('agent'    => $agent,
                     'name'     => $name,
                     'id'       => $id,
                     'version'  => $version,
                     'impl'     => $impl);

    
    debug "Object %s", dump($object);

    my $plugins = $self->plugins;
    $plugins ||= [];
    push @$plugins, $object;
    $self->plugins($plugins);
}

1;
# vi: set ts=4 sw=4:
# vi: set expandtab:
