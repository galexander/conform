package Conform::Runtime;

=head1  NAME
    
    Conform::Runtime

=head1  ABSTRACT

    Base Conform::Runtime class - intended to be extended by device specific Runtimes

=head1  SYNOPSIS

    package Conform::Runtime::Special;
    use Any::Mouse;

    our $VERSION = 0.1;
    
    extends 'Conform::Runtime';

=head1  DESCRIPTION

Conform::Runtime is a base class that must be extended by something more device
or operating system specific.

All runtimes must extend Conform::Runtime.

=cut

use Mouse;
use Mouse::Util::TypeConstraints;
use Scalar::Util qw(blessed);
use Data::Dumper;
use Data::Dump qw(dump);
use Conform::Debug qw(Debug Trace);
use Carp qw(croak);
use Conform;

our $VERSION = $Conform::VERSION;

=head1  Methods

=head2  new

    Conform::Runtime->new();

=head3 Parameters 

None

=over

sub BUILD {
    my $self = shift;
    my $name    = $self->name;
    my $version = $self->version;
    my $id      = $self->id;

    die "\$VERSION not set for @{[$name]}"
        unless defined $version;

    $self;
}

=head2 name

    my $name = $runtime->name;

Get the runtime name - the package name

=head3 Parameters 

None

=head3 Returns

=over

=item * $name

    The name of this runtime

=back

=cut

sub name {
    my $package = shift;
    return blessed $package || $package || __PACKAGE__;
}

=head2 version

    my $version = $runtime->version;

Get the runtime version - $VERSION

=head3 Parameters 

None

=head3 Returns

=over

=item * $version

    The version of this runtime

=back

=cut

sub version {
    my $self = shift;
    my $name = $self->name;
    no strict 'refs';
    return ${"${name}\::VERSION"}
}

=head2 id

    my $id = $runtime->id;

Get the runtime id

=head3 Parameters

None

=head3 Returns

=over

=item * $id

    The id of this runtime

=back

=cut

sub id {
    return sprintf "%s-%s", $_[0]->name, $_[0]->version;
}

=head2 inheritance

    my $inheritance = $runtime->inheritance;
    for (@$inheritance) {
        ...
    }

Get all the 'classes' that this runtime inherits from.
Generally useful for determining plugin resolution.

=head3 Parameters

None

=head3 Returns

=over

=item * \@inheritance

    The inheritance of this runtime as an ArrayRef

=back

=cut

##
# _traverse_inheritance ($package, &callback)
# recursive helper function that traverses the 
# @ISA of '$package' and executes callback->($parent)
# for each parent found.

sub _traverse_inheritance;
sub _traverse_inheritance {
    my $package = shift;
    my $method  = shift;

    no strict 'refs';
    if (defined @{"${package}\::ISA"}) {
        for my $isa (@{"${package}\::ISA"}) {
            $method->($isa);
            _traverse_inheritance $isa, $method;
        }
    }
}

has 'inheritance' => (
    'is' => 'ro',
    'isa' => 'ArrayRef',
    'writer' => '_set_inheritance',
    'default' => sub {
        my $self = shift;
        my $package = blessed $self;
        my @runtimes = ();
        _traverse_inheritance $package, sub {
            push @runtimes, $_[0] if $_[0]->isa(__PACKAGE__);
        };
        \@runtimes;
    },
);

=head2 providers

    my $providers = $runtime->providers;
    for my $provider_type (keys %$providers) {
        for my $provider (@{$providers->{$provider_type}) {
            ...
        }
    }

=head3 Parameters

None

=head3 Returns

=over

=item * \%providers

The function providers, or runtime plugins
of this runtime as a HashRef.
Function providers can be either:

=over

=item Data

Runtime 'Data' plugins are plugins that provide methods to
get data, or information from the runtime.

See L<Conform::Data>

=item Action

Runtime 'Action' plugins are plugins that provide methods to 
execute 'Actions' for this runtime.

See L<Conform::Action>

=item Task

Runtime 'Task' plugins are plugins that provide methods to
execute 'Tasks' for this runtime.

See L<Conform::Task>

=back

=back

=cut


has providers => (
    is => 'ro',
    isa => 'HashRef',
    default => sub { {} },
    writer => '_set_providers',
);

=head2 data_providers

    my $providers = $runtime->data_providers;
    for my $provider (@{$providers}) {
        ...
    }

=head3 Parameters

None

=head3 Returns

=over

=item * \@data_providers

The data provider plugins of this runtime as an ArrayRef

Runtime 'Data' plugins are plugins that provide methods to
get data, or information from the runtime.

See L<Conform::Data>

=back

=cut

sub data_providers {
    my $self = shift;
    my $providers = $self->providers;
    return wantarray
            ? @{$providers->{Data} ||=[]}
            :  ($providers->{Data} ||=[]);
}

=head2 action_providers

    my $providers = $runtime->data_providers;
    for my $provider (@{$providers}) {
        ...
    }

=head3 Parameters

None

=head3 Returns

=over

=item * \@action_providers

The action provider plugins of this runtime as an ArrayRef

Runtime 'Action' plugins are plugins that provide methods to 
execute 'Actions' for this runtime.

See L<Conform::Action>

=back

=cut

sub action_providers {
    my $self = shift;
    my $providers = $self->providers;
    return wantarray
            ? @{$providers->{Action} ||=[]}
            :  ($providers->{Action} ||=[]);

}

=head2 task_providers

    my $providers = $runtime->task_providers;
    for my $provider (@{$providers}) {
        ...
    }

=head3 Parameters

None

=head3 Returns

=over

=item * \@task_providers

The task provider plugins of this runtime as an ArrayRef

Runtime 'Task' plugins are plugins that provide methods to
execute 'Tasks' for this runtime.

See L<Conform::Task>

=back

=cut

sub task_providers {
    my $self = shift;
    my $providers = $self->providers;
    return wantarray
            ? @{$providers->{Task} ||=[]}
            :  ($providers->{Task}  ||=[]);
}

=head2 register_provider

    $runtime->register_provider($provider);

Register a provider/plugin with this runtime.

=head3 Parameters

=over

=item $provider - A Conform::Plugin to register with this runtime.

=back

=head3 Returns

None

=cut

sub register_provider {
    my $self     = shift;
    my $provider = shift;
    my $type     = $provider->type;
    
    Debug "Registering %s %s",
          $type,
          $provider->name;

    my $providers = $self->providers;
    $providers->{$type} ||= [];
    push @{$providers->{$type}}, $provider;

    return $provider;
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

=head2 boot

    $runtime->boot();

"Boots" this runtime.  Booting is the process of
loading ALL plugins for this and parent runtimes.
Where ALL plugins are 'Data', 'Action', and 'Task'.

=head3 Parameters

None

=head3 Returns

None

=cut

sub _discover_providers {
    my $self = shift;
    my $type = shift;

    Trace;

    my $package = blessed $self;

    Debug "Discovering %s provider for %s",
                lc $type,
                $package; 
    
    my $loader = "Conform::${type}::PluginLoader";
    eval "use $loader;";
    die "$@" if $@;

    $loader = $loader->new(plugin_type => $type);

    Debug "%s", dump ($loader);

    my $plugins = $loader->get_plugins(search_path => [ $package, @{$self->inheritance} ]);

    Debug "Plugins %s", dump($plugins);

    for (@$plugins) {
        $self->register_provider($_);
    }
}

sub boot {
    my $self = shift;

    Trace;

    Debug "Booting runtime %s", $self->id;

    my $package = blessed $self;

    my @runtimes = @{$self->inheritance};
    
    Debug "Runtime Inheritance Chain = %s", dump(\@runtimes);
    
    Debug "Loading action providers for %s", $package;
    $self->_discover_providers
        ('Action');

    Debug "Loading task providers for %s",  $package;
    $self->_discover_providers
        ('Task');

    Debug "Loading data providers for %s",  $package;
    $self->_discover_providers
        ('Data');

    $self;
}

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=head1  COPYRIGHT

Copyright 2012 (Gavin Alexander)

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module

=cut

1;
# vi: set ts=4 sw=4:
# vi: set expandtab:
