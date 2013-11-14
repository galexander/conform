package Conform::Module;
use strict;
use Scalar::Util qw(blessed);
use Module::Pluggable require => 1;
use OIE::Conform qw(i_isa i_isa_fetchall i_isa_mergeall type_list);
use Carp qw(croak carp);
use Storable qw(dclone);
use Hash::Merge qw(merge);
use Data::Dumper;
use Conform::Module::Machines;

our $DEBUG = 0;

=head1  NAME

Conform::Module;

=head1  SYNOPSIS

    # in machines.cfg
    our %m;
    our $_path;
    our $iam;
    our $class;

    use Conform::Module 
            -machines   => \%m,
            -path       => $_path,
            -iam        => $iam,
            -class      => $_class
            -run        => 1;

    # or

    use Conform::Module;
    Conform::Module->run(
            -machines   => \%m,
            -path       => $_path,
            -iam        => $iam,
            -class      => $_class
            -run        => 1);

=cut

sub import {
    my $package = shift;
    my $caller  = caller;
    $caller = $caller eq __PACKAGE__
                ? caller(1)
                : $caller;

    my $iam;
    my $machines;
    my $class;
    my $path;
    my $env;
    my @args = @_;

    my %vars;

    if (@args && @args % 2 == 0) {
        %vars = @args;
        $iam        = delete $vars{'-iam'};
        $machines   = delete $vars{'-machines'};
        $class      = delete $vars{'-class'};
        $path       = delete $vars{'-path'};
        $env        = delete $vars{'-env'};
    }

    no strict 'refs';
    no warnings;
    $machines ||= ${"${caller}\::m"};
    $iam      ||= ${"${caller}\::iam"};
    $class    ||= ${"${caller}\::_class"};
    $path     ||= ${"${caller}\::_path"};
    $env      ||= ${"${caller}\::_env"};

    my $run = $vars{'-run'};

    unshift @INC, "$path/lib"
        unless grep /^$path\/lib$/, @INC;

    if ($run) {

        $machines = Conform::Module::Machines->new(path => $path,
                                                   iam => $iam,
                                                   class => $class,
                                                   machines => $machines,
                                                   env => $env);

        for my $module (__PACKAGE__->modules(search_dirs => ["${path}/lib"])) {
            eval "use $module;";
            die "$@" if $@;
            $module->conform(machines => $machines,
                             iam      => $iam,
                             class    => $class,
                             path     => $path,
                             env      => $env) if $module->can('conform');
        }
    }
}

sub new {
    my $package = shift;
    my $class = ref $package || $package || __PACKAGE__;
    UNIVERSAL::can($class, 'conform')
        and UNIVERSAL::can($class, 'tag')
            or croak "$class does not implement 'tag' and 'conform'";

    my $self = bless { } => $class;
    my %args = 
        ref $_[0] eq 'HASH'
            ? %{$_[0]}
            : (ref $_[0] eq 'ARRAY'
                ? (@{$_[0]} % 2 == 0
                    ? %{$_[0]}
                    : croak "usage: $class->new(key => val, ..., key => val)")
                : (@_ % 2 == 0
                    ? @_
                    : croak "usage: $class->new(key => val, ..., key => val)"));
            

    for (grep { $self->can($_) } keys %args) {
        $self->$_($args{$_});
    }

    $self->machines
        or croak "missing required parameter 'machines'";

    $self->iam
        or croak "missing required parameter 'iam'";

    $self->path
        or croak "missing required parameter 'path'";

    $self;
}

sub machines {
    my $self = shift;
    if (@_) {
        ref $_[0] eq 'HASH' or (blessed $_[0] && $_[0]->isa('Conform::Module::Machines'))
            or croak "invalid value for 'machines'";
        
        $self->{'_machines'} = shift @_;
    }
    $self->{'_machines'};
}

sub iam {
    my $self = shift;
    if (@_) {
        $self->{'_iam'} = shift @_;
    }
    $self->{'_iam'};
}

sub path {
    my $self = shift;
    if (@_) {
        $self->{'_path'} = shift @_;
    }
    $self->{'_path'};
}

sub class {
    my $self = shift;
    if (@_) {
        $self->{'_class'} = shift @_;
    }
    $self->{'_class'};
}

sub tag {
    my $self  = shift;
    my $class = ref $self;
    $class =~ s/@{[__PACKAGE__]}:://;
    return $class;
}

sub tags {
    my $self  = shift;
    return ($self->tag);
}

sub env {
    my $self = shift;
    if (@_) {
        $self->{'_env'} = shift @_;
    } else {
        if ($self->machines && $self->iam) {
            $self->{'_env'} = i_isa $self->machines->nodes,
                                    $self->iam,
                                    'Env';
        }
    }
    $self->{'_env'};
}

sub global_config {
    my $self = shift;
    if (my $global_config = $self->{'_global_config'}) {
        return $global_config;
    } else {
        my $machines  = $self->machines->nodes;
        my @tags = $self->tags;
        push @tags, map { ("${_}::Vars", "${_}::Defaults") } @tags;
        my %global_config = ();
        for my $tag (@tags) {
            for my $host (type_list $machines, $tag) {
                $global_config{$host} ||= { };
                
                my $merged_config = dclone i_isa_mergeall $machines, $host, $tag;

                if (exists $global_config{$host}{$tag}) {
                    $global_config{$host}{$tag}
                                = merge $global_config->{$host}{$tag},
                                        $merged_config;
                } else {
                    $global_config{$host}{$tag} = $merged_config;
                }
            }
        }

        return $self->{'_global_config'} = \%global_config;
    }
}

# validate configuration
sub validate {
    my $self   = shift;
    my $config = shift;
    my %check  = @_;

    my %ok;

    for my $var (keys %check) {
        my $value = $self->get_default($var => $check{$var})
                        or croak "$var is not set";
        $ok{$var} = $value;
    }
    return %ok;
}


sub config {
    my $self = shift;
    if (my $config = $self->{'_config'}) {
        return $config;
    } else {
        my $global_config = $self->global_config;
        my $for = shift @_ || $self->tag;
        my $config = $global_config->{$self->iam}{$for};
        return $self->{'_config'} = $config;
    }
}

sub _get_global {
    my $self  = shift;
    my $thing = shift;
    my $field = sprintf "_%s", $thing;
    if (my $value = $self->{$field}) {
        return $value;
    } else {
        my $global_config = $self->global_config;
        my $tag = shift @_ || $self->tag;
        $tag = sprintf "%s::%s", $tag, ucfirst $thing;
        $self->{$field} = $global_config->{$self->iam}{$tag} || {};
        return $self->{$field};
    }
}

sub get_vars {
    my $self = shift;
    return $self->_get_global('vars');
}

sub get_defaults {
    my $self = shift;
    return $self->_get_global('defaults');
}

sub get_default {
    my $self     = shift;
    my $key      = shift;
    my $override = shift;
    my $defaults = dclone $self->get_defaults;
    my $vars     = dclone $self->get_vars;

    my $return = defined $override
            ? $override
            : (exists $defaults->{$key}
                ? $defaults->{$key}
                : (exists $vars->{$key}
                        ? $vars->{$key}
                        : $override));
    

    if (defined $return and ! ref $return) {
        1 while $return =~ s|\${conform\.(\S+)}|my $method = sprintf "%s", $1; $self->can($method) ? $self->$method() : "\${$1}"|ge;
        1 while $return =~ s|\${(\S+)}|exists $defaults->{$1} ? $defaults->{$1} : $1|ge;
        1 while $return =~ s|\${(\S+)}|exists $vars->{$1} ? $vars->{$1} : $1|ge;
    }

    return $return;
}

sub conform { 
    die "Override me!"
}

sub register {
    my $self  = shift;
    my $thing = shift;
    $self->{"_register"}{$thing}++;
}

sub registered {
    my $self  = shift;
    my $thing = shift;
    return $self->{"_register"}{$thing};
}

sub modules {
    my $package = shift;
    my %args    = @_;
    $args{'search_path'} ||= __PACKAGE__;
    $args{'require'} = 0;
    $args{'inner'} = 0;
    $args{'except'} = qr/^@{[__PACKAGE__]}::(Util|Machines|Debug)/;
    my @found   = ();
    {
        local @INC = ();
        my $finder = Module::Pluggable::Object->new(%args);
        @found = $finder->plugins();
    }
    my @plugins = ();
    PLUGIN:
    for my $plugin (@found) {
        local $@;
        eval "CORE::require $plugin;";
        if (my $err = $@) {
            carp "$err";
        } else {
            push @plugins, $plugin
                if $plugin->isa(__PACKAGE__) &&
                   $plugin ne __PACKAGE__ &&
                   $plugin->can('conform') &&
                   $plugin->can('tag');
        }
    }
    return wantarray
        ? @plugins
        :\@plugins;
}


1;
