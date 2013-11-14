package Conform::Module::Machines;
use strict;
use Exporter;
use Carp qw(croak);
use YAML ();
our @ISA;
our @EXPORT;
our @EXPORT_OK;
use OIE::Conform qw(i_isa);
use OIE::Utils qw(slurp_file);
use Hash::Merge qw(merge);
use Scalar::Util qw(weaken blessed);
use Sys::Hostname qw(hostname);
use FindBin;

@ISA = qw/ Exporter /;

sub new {
    my $klass = shift;
    my %args  = @_;

    my $self     = bless {}, ref $klass || $klass || __PACKAGE__;
    my $iam      = $args{iam} || hostname;
    my $machines = $args{machines} || {};
    my $path     = $args{path}  || "$FindBin::Bin";
    my $class    = $args{class} || __PACKAGE__;
    my $env      = $args{env}   || i_isa $machines, $iam, 'Env';
    

    $self->load_env_machines(iam      => $iam,
                             machines => $machines,
                             path     => $path,
                             class    => $class,
                             env      => $env);

    $self;
}

my %context = ();

sub _context_variable {
    my $context  = shift @_;
    my $variable = shift @_;
    if (@_) {
        my $value = shift @_;
        $context{$context}{$variable} = $value;
        weaken $context{$context}{$variable}
                if ref $context{$context}{$variable};
    } 

    return $context{$context}{$variable}
        if exists $context{$context}
       and exists $context{$context}{$variable};

    croak "value not set for $context -> $variable";
}

sub _exportable {
    my $var = shift;
    return 0 if ref $var;
    return 0 unless defined $var;
    return 0 unless length $var;
    return 1 if grep /^\Q$var\E$/, @EXPORT;
    return 0;
}


sub import {
    __PACKAGE__->export_to_level(1, grep {_exportable $_} @_);
    my $package = shift;

    if (grep /load/, @_) {

        my $caller  = caller;
        $caller = $caller eq __PACKAGE__
                    ? caller(1)
                    : $caller;

        my $iam;
        my $m;
        my $class;
        my $path;
        my $env;

        my @args = grep {!_exportable $_} @_;

        if (@args && @args % 2 == 0) {
            my %vars = @_;
            $iam        = delete $vars{iam}     || delete $vars{conform_iam};
            $m          = delete $vars{machines}|| delete $vars{conform_machines};
            $class      = delete $vars{class}   || delete $vars{conform_class};
            $path       = delete $vars{path}    || delete $vars{conform_path};
            $env        = delete $vars{env}     || delete $vars{conform_env};
        }

        no strict 'refs';
        no warnings;
        $iam   ||= ${"${caller}\::iam"}   || ${"${caller}\::conform_iam"};
        $class ||= ${"${caller}\::_class"}|| ${"${caller}\::conform_class"};
        $path  ||= ${"${caller}\::_path"} || ${"${caller}\::conform_path"};
        $env   ||= ${"${caller}\::_env"}  || ${"${caller}\::conform_env"};
        unless (defined $m) {
            SEARCH: for (qw(m conform_machines machines conform_m)) {
                if (defined *{"${caller}\::${_}"}{HASH}) {
                    $m = \%{"${caller}\::${_}"};
                    last SEARCH;
                }
            }
        }

        $env ||= i_isa $m, $iam, 'Env'
            if defined $m and defined $iam;

        $class || __PACKAGE__;

        _context_variable $caller, 'machines', $m                     if defined $m;
        _context_variable $caller, 'iam',      $iam                   if defined $iam;
        _context_variable $caller, 'path',     $path                  if defined $path;
        _context_variable $caller, 'class',    $class;
        _context_variable $caller, 'env',      $env;

        $package->new (machines => $m,
                     iam => $iam,
                     path => $path,
                     class => $class,
                     env => $env);

    }

}

sub _override_context {
    my ($context, $provided) = @_;

    my %defaults = ();
    for my $key (keys %$provided) {
        $defaults{$key} = $provided->{$key}
            if exists $provided->{$key};
    }
    
    $defaults{machines} ||= _context_variable $context, 'machines';
    $defaults{class}    ||= _context_variable $context, 'class';
    $defaults{iam}      ||= _context_variable $context, 'iam';
    $defaults{env}      ||= _context_variable $context, 'env';
    $defaults{path}     ||= _context_variable $context, 'path';

    return \%defaults;
}

sub load_env_machines {
    my $self = shift;
    
    my %args = @_;
    my $context = caller(1);

    my $vars = _override_context $context, \%args;

    my $m     = $vars->{machines};
    my $class = $vars->{class};
    my $iam   = $vars->{iam};
    my $env   = $vars->{env};
    my $path  = $vars->{path};

    $env ||= i_isa $m, $iam, 'Env';

    $env || die "'Env' not set for $iam";

    my %global_yaml_vars = (
        'ENV'  => $env,
        'PATH' => $path,
        'IAM'  => $iam
    );

    my %default_yaml_vars = %global_yaml_vars;
    my %env_yaml_vars = ();
    my $cfg = {};
    

    if (-f "${path}/machines.yaml.${env}") {
        $cfg = _load_yaml("${path}/machines.yaml.${env}");
        %env_yaml_vars = %default_yaml_vars;
        %env_yaml_vars = (%env_yaml_vars, %{$cfg->{vars}})
                            if exists $cfg->{vars} and
                                  ref $cfg->{vars} eq 'HASH';
        $cfg = _load_yaml("${path}/machines.yaml.${env}", \%env_yaml_vars);

    } else {
        if (-f "${path}/machines.yaml") {
            $cfg = _load_yaml("${path}/machines.yaml");
            %env_yaml_vars = %default_yaml_vars;
            %env_yaml_vars = (%env_yaml_vars, %{$cfg->{vars}})
                                if exists $cfg->{vars} and
                                      ref $cfg->{vars} eq 'HASH';
       
            %env_yaml_vars = (%env_yaml_vars, %{$cfg->{default}{vars}})
                                if exists $cfg->{default} &&
                                      ref $cfg->{default} eq 'HASH' &&
                                   exists $cfg->{default}{vars} &&
                                      ref $cfg->{default}{vars} eq 'HASH';

            %env_yaml_vars = (%env_yaml_vars, %{$cfg->{$env}{vars}})
                                if exists $cfg->{$env} &&
                                      ref $cfg->{$env} eq 'HASH' &&
                                   exists $cfg->{$env}{vars} &&
                                      ref $cfg->{$env}{vars} eq 'HASH';

            $cfg = _load_yaml("${path}/machines.yaml", \%env_yaml_vars);
            $cfg = $cfg->{default}
                    if exists $cfg->{default} &&
                          ref $cfg->{default} eq 'HASH';

            $cfg = merge($cfg->{$env}, $cfg)
                if (exists $cfg->{$env} &&
                       ref $cfg->{$env} eq 'HASH');
        }
    }
    my $machines_cfg = $cfg->{m} || $cfg->{machines} || {};
    $m->{$class} = $machines_cfg;
    $self->{'_m'} = $m;
}

sub _load_yaml {
    my $file = shift;
    my $vars = shift;
    my $data = {};
    if ($vars and ref $vars eq 'HASH') {
        my $yaml = slurp_file $file;
        1 while $yaml =~ s/%{var:(.+?)}/exists $vars->{$1} ? $vars->{$1} : "%{var:$1}"/ge;
        $data = YAML::Load($yaml);
    } else {
        $data = YAML::LoadFile($file);
    }
    return $data;
}

sub nodes {
    my $self = shift;
    return $self->{'_m'};
}



1;
