package Conform::Runtime;

=head1  NAME
    
    Conform::Runtime

=head1  ABSTRACT

    Base Conform::Runtime class - intended to be extended by device specific Runtimes

=head1  SYNOPSIS

    package Conform::Special::Runtime;
    use Any::Mouse;
    
    extends 'Conform::Runtime';

    Name "Special::Runtime";
    Version "0.1";
    ID "Special::Runtime-0.1";

    sub special_method {
        # do special stuff here
    }

=head1  DESCRIPTION

Conform::Runtime is a base class that must be extended by something more 'runtime' device
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

In most cases these will be left blank, in which case sensible defaults are chosen.
See below for more information.

Also, you can specify these using the syntactic sugar.  See L<SYNTACTIC SUGAR> below.

=head3 Parameters 

=over

=item * name (OPTIONAL)

A name for this runtime.  The name must adhere to Perl module package naming conventions.
Examples include 'Runtime::Linux' or 'my::runtime'.
Try 'man perlmod', or 'man perlmodlib' on your machine for naming.

If its not supplied it defaults to the Perl package name that defines the Runtime.

=item * version (OPTIONAL)

A version for this runtime.  The version must adhere to the Perl version specification.
Examples include '0.1', '1', 'v0.2'.

If its not supplied then its set to $VERSION for the Perl package that defines the Runtime.
If this is not set - then an error is thrown.

=item * id (OPTIONAL)

An id for this runtime.  The id can only contain valid characters in L<name> and <version>.
Or more specifically,

    ^[a-zA-Z\:\.0-9\-]+$

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


has 'name' => (
    is => 'rw',
    isa => 'RuntimeName'
);

has 'version' => (
    is => 'rw',
    isa => 'RuntimeVersion',
);

has 'id' => (
    is => 'rw',
    isa => 'RuntimeID',
);


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

no Mouse;

sub action_providers {
    my $self = shift;
    my $providers = $self->providers;
    return wantarray
            ? @{$providers->{Action} ||=[]}
            :  ($providers->{Action} ||=[]);

}

sub task_providers {
    my $self = shift;
    my $providers = $self->providers;
    return wantarray
            ? @{$providers->{Task} ||=[]}
            :  ($providers->{Task}  ||=[]);

}



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

    Debug "Loading task providers for %s",  blessed $self;
    $self->_discover_providers
        ('Task');

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

    my $plugins = $loader->get_plugins(search_path => $self->ancestors);

    Debug "Plugins %s", dump($plugins);

    for (@$plugins) {
        $self->register_provider($type => $_);
    }

}

1;
