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

1;
# vi: set ts=4 sw=4:
# vi: set expandtab:
