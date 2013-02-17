package Conform::Action::PluginLoader;
use Mouse;
use Conform::Debug qw(Trace Debug);
use Data::Dump qw(dump);

with 'Conform::PluginLoader';

sub _find_attr {
    my ($name, $attr) = @_;

    Trace;

    for my $attribute (@{$attr ||[]}) {
        my ($key, $value) = ref $attribute eq 'HASH'
                                ? each %$attribute
                                :@$attribute;
        if ($key eq $name) {
            return $value;
        }
    }
    return undef;
}

sub _find_attrs {
    my ($name, $attr) = @_;

    Trace;

    my @attr = ();
    for (@{$attr || []}) {
        my ($key, $value) = each %$_;
        if ($key eq $name) {
            push @attr, $value;
        }
    }
    return wantarray
        ? @attr
        :\@attr;
}

sub _parse_arg_spec {
    my $format = shift;
    my @spec;
    my $identifier;
    for my $arg (split /,/, $format) {
        $arg =~ s/^\s+//g;
        $arg =~ s/\s+$//g;
        my %spec = ();
        my $required;
        my $type;
        if ($arg =~ s/^\+//) {
            $required++
        }
        if ($arg =~ s/^(%|@)//) {
            $type = $1 eq '%'
                        ? 'HASH'
                        : 'ARRAY';
        }
        %spec = (
            'arg'      => $arg,
            'required' => $required,
            'type'     => $type,
        );
        
        unless (defined $identifier) {
            $identifier = $spec{identifier}
                        = $arg;
        }
        push @spec, \%spec;
    }
    return \@spec;

}

sub register {
    my $self   = shift;
    Debug "Register %s", dump(\@_);
    my %args = @_;
    my ($agent, $plugin, $name, $id, $version, $impl, $attr)
        = @args{qw(agent plugin name id version impl attr)};

    $attr ||= [];
    

    Debug "$plugin, $name, $id,  $version, $attr";

    Trace;

    if (my $value = _find_attr 'Action', $attr) {
        Debug "override 'Action' ($name -> $value)";
        $name = $value;
    }

    if (defined(my $value = _find_attr 'Version', $attr)) {
        Debug "override 'Version' ($version -> $value)";
        $version = $value;
    }

    if (my $value = _find_attr 'Id', $attr) {
        Debug "override 'Id' ($id => $value)";
        $id = $value;
    }
    

    my $arg_spec = _find_attr 'Args', $attr;
    unless ($arg_spec) {
        $arg_spec = _find_attr 'Params',  $attr;
    }

    if ($arg_spec) {
        $arg_spec = _parse_arg_spec $arg_spec;
    }

    my $object = 
        $plugin->new('agent'    => $agent,
                     'name'     => $name,
                     'id'       => $id,
                     'version'  => $version,
                     'attr'     => $attr,
                     'impl'     => $impl,
                     'arg_spec' => $arg_spec);

    
    Debug "Object %s", $object;

    my $plugins = $self->plugins;
    $plugins ||= [];
    push @$plugins, $object;
    $self->plugins($plugins);
}

sub get_plugins {
    my $self = shift;

    Trace;

    my $finder = $self->plugin_finder;
    
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
