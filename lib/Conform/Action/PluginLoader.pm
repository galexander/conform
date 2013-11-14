package Conform::Action::PluginLoader;
use Moose;
use Conform::Logger qw($log trace debug notice warn fatal);
use Data::Dump qw(dump);

with 'Conform::PluginLoader';

sub _find_attr {
    my ($name, $attr) = @_;

    trace;

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

    trace;

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
    debug "Register %s", dump(\@_);
    my %args = @_;
    my ($agent, $plugin, $name, $id, $version, $impl, $attr)
        = @args{qw(agent plugin name id version impl attr)};

    $attr ||= [];
    

    debug "$plugin, $name, $id,  $version, $attr";

    trace;

    if (my $value = _find_attr 'Action', $attr) {
        debug "override 'Action' ($name -> $value)";
        $name = $value;
    }

    if (defined(my $value = _find_attr 'Version', $attr)) {
        debug "override 'Version' ($version -> $value)";
        $version = $value;
    }

    if (my $value = _find_attr 'Id', $attr) {
        debug "override 'Id' ($id => $value)";
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

    
    debug "Object %s", $object;

    my $plugins = $self->plugins;
    $plugins ||= [];
    push @$plugins, $object;
    $self->plugins($plugins);
}

1;
# vi: set ts=4 sw=4:
# vi: set expandtab:
