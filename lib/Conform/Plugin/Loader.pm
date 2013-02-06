package Conform::Plugin::Loader;
use Mouse::Role;
use Conform::Logger qw($log);
use Data::Dump qw(dump);
use attributes;
use Module::Pluggable;

=head1  NAME

Conform::Plugin::Loader

=head1  SYNSOPSIS

use Conform::Plugin::Loader;

=head1  DESCRIPTION

=cut

=head1   METHODS

=cut

has 'plugins' => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { [] } 
);

has 'plugin_type' => (
    is => 'rw',
    isa => 'Str',
);

sub get_plugin_type {
    my $self = shift;
    my $type = $self->plugin_type;
    unless ($type) {
        my $class = ref $self;
        ($type = $class) =~ s/^Conform::(\S+)/$1/;
    }
    return $self->plugin_type($type);
}

sub register {
    my $self   = shift;
    my $plugin = shift;
    my $plugins = $self->plugins;
    $plugins ||= [];
    push @$plugins, $plugin;
    $self->plugins($plugins);
}

sub plugin_resolver {
    my $self = shift;
    my $type = $self->get_plugin_type;
    return new Module::Pluggable::Object
                    search_path => [ "Conform::${type}" ],
                    except => qr/^Conform::\S+::Plugin/,
                    require => 0;
}

sub plugin {
    my $self = shift;
    my $class  = ref $self;
    my $source = shift;

    my $plugin = $source;
    my $plugin_type = sprintf "Conform::%s", $self->get_plugin_type;

    $log->debug("plugging in $plugin_type from $source");

    $source =~ s/::/\//g;
    $source.= '.pm'
        unless $source=~ /\.\S+$/;

    eval {
        eval <<EOPLUGIN;
do '$source';
EOPLUGIN
        if (my $err = $@) {
            die $err;
        }

        if (UNIVERSAL::isa($plugin, $plugin_type)) {
            (my $name = $source) =~ s!^.*/(\S+)\.(\S+)?!$1!;
            $log->debug("$plugin isa $plugin_type");
            $self->register($plugin_type->new(name => $name));
            return;
        }

        sub _get_type_names {
            my ($type, $field, @list) = @_;

            my @names = ();

            ATTR: for my $attr (@list) {
                if ($attr =~ /^\Q$type\E(?!\((\S+)\))?$/) {
                    my $name = $1 || $field;
                    push @names, $name
                        unless grep /^$name$/, @names;
                }
            }

            if ($field =~ s/_\Q$type\E$//) {
                push @names, $field
                    unless grep /^$field$/, @names;
            }

            if ($field =~ /^[A-Z][a-z]+/) {
                push @names, $field
                    unless grep /^$field$/, @names;
            }

            return @names;
        }

        my $type = $self->get_plugin_type;

        no strict 'refs';
        for my $field (keys %{"${plugin}\::"}) {
            next unless defined \&{"${plugin}\::${field}"};
            my @attr = attributes::get(\&{"${plugin}\::${field}"});

            for my $name (_get_type_names $type, $field, @attr) {
                $log->debugf("%s::%s is a '%s'", $plugin, $name, $type);

                my $object = $plugin_type->new(name => $name, impl => \&{"${plugin}\::${field}"});
                $self->register($object);
            }
        }
    };
    if (my $err = $@) {
        $log->error("Error loading plugin $plugin: $@");
    }
}

=head1  SEE ALSO

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

1;

# vi: set ts=4 sw=4:
# vi: set expandtab:
