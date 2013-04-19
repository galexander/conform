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

    Conform::Runtime->new(name => 'foo', version => '0.1', id => 'foo-0.1');

In most cases these parameters are not required. Sensible defaults are chosen.
See below for more information.

=head3 Parameters 

=over

=item * name (OPTIONAL)

A name for this runtime.  The name must adhere to Perl module package naming conventions.
Examples include 'Runtime::Linux' or 'my::runtime'.
Try 'man perlmod', or 'man perlmodlib' on your machine for naming.

If its not supplied it defaults to the Perl package name that defines the Runtime.

The explicit check is:

    my $runtime_name_regex    = qr/^[A-Za-z]+((::[A-Za-z]+)+)?$/;

=item * version (OPTIONAL)

A version for this runtime.  The version must adhere to the Perl version specification.
Examples include '0.1', '1', 'v0.2'.

If its not supplied then its set to $VERSION for the Perl package that defines the Runtime.
If this is not set - then an error is thrown.

The explicit check is:

    my $runtime_version_regex = qr/^v?[0-9]+(\.[0-9])?[0-9]?$/;

=item * id (OPTIONAL)

An id for this runtime.  The id can only contain valid characters as defined in L<name> and L<version>.

The explicit check is:

    my $runtime_id_regex      = qr/^$runtime_name_regex-$runtime_version_regex$/;

=back

=cut

sub BUILD {
    my $self = shift;
    my $name    = $self->name;
    my $version = $self->version;
    my $id      = $self->id;

    my $class = blessed $self;
    no strict 'refs';
    unless (defined $name) {
        $self->name($name = $class);
    }

    unless (defined $version) {
        $self->version($version = ${"${class}\::VERSION"});
    }

    unless (defined $id) {
        $self->id(sprintf "%s-%s", $name, $version);
    }
    $self;
}

# Declare some 'subtypes' for validation

my $runtime_name_regex    = qr/[A-Za-z]+((::[A-Za-z]+)+)?/;
my $runtime_version_regex = qr/v?[0-9]+(\.[0-9])?[0-9]?/;
my $runtime_id_regex      = qr/$runtime_name_regex-$runtime_version_regex$/;

subtype 'RuntimeName',
    as 'Str',
    where { /^$runtime_name_regex$/ },
    message { "invalid value $_ for runtime 'name'" };

subtype 'RuntimeVersion',
    as 'Str',
    where { /^$runtime_version_regex$/ },
    message { "invalid value $_ for runtime 'version'" };

subtype 'RuntimeID',
    as 'Str',
    where { /^$runtime_id_regex$/ },
    message { "invalid value $_ for runtime 'id'" };


=head2 name

    my $name = $runtime->name;

Get the runtime name - which was set during object
construction.

=head3 Parameters 

None

=head3 Returns

=over

=item * $name

    The name of this runtime

=back

=cut

has 'name' => (
    is => 'rw',
    isa => 'RuntimeName'
);

=head2 version

    my $version = $runtime->version;

Get the runtime version - which was set during object
construction.

=head3 Parameters 

None

=head3 Returns

=over

=item * $version

    The version of this runtime

=back

=cut

has 'version' => (
    is => 'rw',
    isa => 'RuntimeVersion',
);

=head2 id

    my $id = $runtime->id;

Get the runtime id - which was set during object
construction.

=head3 Parameters

None

=head3 Returns

=over

=item * $id

    The id of this runtime

=back

=cut

has 'id' => (
    is => 'rw',
    isa => 'RuntimeID',
);


# Add some constraints - these values can only be set once.
# During object construction.  We don't specify as 'required'
# as they can be determined post construction and can 
# depend on each other.

around [qw(name)] => sub {
    my $orig = shift;
    my $self = shift;

    my $value = $self->$orig();
    @_ and defined $value and croak "'name' is already set to $value";
    $self->$orig(@_);
};

around [qw(version)] => sub {
    my $orig = shift;
    my $self = shift;

    my $value = $self->$orig();
    @_ and defined $value and croak "'version' is already set to $value";
    $self->$orig(@_);
};

around [qw(id)] => sub {
    my $orig = shift;
    my $self = shift;

    my $value = $self->$orig();
    @_ and defined $value and croak "'id' is already set to $value";
    $self->$orig(@_);
};


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

has pending_providers => (
    is => 'ro',
    isa => 'HashRef',
    default => sub => { {} },
);

no Mouse;

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

sub _extract_requires {
    my $type  = shift;
    my $check = shift;
    my %extract = ();

    for my $key (keys %$check) {
        if ($key =~ /^$type\.(\S+)/) {
            my $param = shift;
            $extract{$param} = $check->{$key};
        }
    }
    return scalar keys %extract
            ? \%extract
            : undef;
}

sub register_provider {
    my $self     = shift;
    my $provider = shift;
    my $type     = $provider->type;
    
    Debug "Attempting to register provider %s %s",
          $provider->name,
          $type;

    my $requires  = $provider->requires;
    
    Debug "Provider has the following requirements %s",
          Dump($requires);

    my @runtime_requires;
    my @provider_requires;

    # collect any requirements
    for (@$requires) {
        if (my $requires = _extract_requires 'runtime', $_) {
            push @runtime_requires, $requires;
        }
        if (my $requires = _extract_requires 'provider', $_) {
            push @provider_requires, $requires;
        }
    }

    my $runtime_ok = 0;

    # check for runtime requirements
    RUNTIME_REQUIRE:
    for my $runtime_require (@$runtime_requires) {
        for my $runtime ((blessed $self, @{[$self->inheritance]})) {
            for my $key (keys %$runtime_require) {
                if ($runtime->can($key) &&
                    $runtime->$key() eq $runtime_require->{$key}) {
                    delete $runtime_require;
                }
            }
            if(scalar (keys %$runtime_require)) {
                $runtime_ok++;
                last RUNTIME_REQUIRE;
            }
        }
    }

    unless ($runtime_ok) {
        warn "Runtime requirements %s not met for %s",
              Dump($runtime_requires),
              $provider->name;
        return;
    }

    # check for provider requirements
    for (@$provider_requires) {
        

    }

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
        $self->register_provider($type => $_);
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
