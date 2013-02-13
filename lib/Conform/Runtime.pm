package Conform::Runtime;
use Mouse;
use Scalar::Util qw(blessed);
use Data::Dumper;
use Data::Dump qw(dump);

use Conform::Debug qw(Debug Trace);
use Conform::Plugin;

has iam => (
    is => 'rw',
    isa => 'Str',
    required => 1,
);

sub action_providers {
    my $self = shift;
    my $providers = $self->providers;
    return wantarray
            ? @{$providers->{Action} ||=[]}
            : ($providers->{Action}  ||=[]);

}
has data_providers => (
    is => 'rw',
    isa => 'ArrayRef',
);

has data => (
    is => 'rw',
);

has 'ancestors' => (
    'is' => 'rw',
    'isa' => 'ArrayRef',
);

has providers => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
);

sub _traverse_inheritance;
sub _traverse_inheritance {
    my $package = shift;
    my $method  = shift;

    $method->($package);

    no strict 'refs';
    if (defined @{"${package}\::ISA"}) {
        for my $isa (@{"${package}\::ISA"}) {
            _traverse_inheritance $isa, $method;
        }
    }
}

sub boot {
    my $self = shift;

    Trace;

    Debug "Booting runtime %s %s", $self->getId(), $self->getVersion();

    my $package = blessed $self;
    Debug "Determining ancestory for @{[ $package ]}";

    my @runtimes = ();
    _traverse_inheritance $package, sub {
        push @runtimes, $_[0]
            if $_[0]->isa(__PACKAGE__);
    };

    Debug "Ancestory = %s", dump(\@runtimes);
    
    $self->ancestors(\@runtimes);

    Debug "Loading action providers for %s", blessed $self;
    $self->_discover_providers
        ('Action');

    Debug "Loading data providers for %s",   blessed $self;
    $self->_discover_providers
        ('Data');

    $self;
}

sub get_data {
    my $self   = shift;
    my $method = shift;

    if ($self->can($method)) {
        return $self->$method(@_);
    }

    my $data_provider = $self->find_data_provider ($method, @_);
    if ($data_provider) {
        $data_provider->resolve(@_);
    }
    return undef;
}

sub call_action {
    my $self = shift;
    my $method = shift;
    
    if ($self->can($method)) {
        return $self->$method(@_);
    }

    my $action_provider = $self->find_action_provider($method, @_);
    if ($action_provider) {
        $action_provider->execute(@_);
    }
    return undef;
}

sub register_provider {
    my $self = shift;
    my $type = shift;
    my $provider = shift;

    my $providers = $self->providers;
    $providers->{$type} ||= [];
    push @{$providers->{$type}}, $provider;
    $provider;
}

sub find_provider {
    my $self = shift;
    my $type = shift;
    my $name = shift;
    my $providers = $self->providers->{$type};
    $providers ||= [];
    for my $provider (@$providers) {
        return $provider
            if $provider->name eq $name;
    }
    return undef;
}



sub _discover_providers {
    my $self = shift;
    my $type = shift;

    Trace;

    my $package = blessed $self;


    Debug "finding %s provider for %s",
                lc $type,
                $package; 
    
    my $loader = "Conform::${type}::PluginLoader";
    eval "use $loader;";
    die "$@" if $@;
    $loader = $loader->new(plugin_type => $type);

    Debug "%s", dump ($loader);

    my $plugins = $loader->get_plugins();

    Debug "Plugins %s", dump($plugins);

    for (@$plugins) {
        $self->register_provider($type => $_);
    }

}
    

1;
