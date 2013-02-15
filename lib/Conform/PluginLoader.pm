package Conform::PluginLoader;
use Mouse::Role;
use Conform::Logger qw($log);
use Data::Dump qw(dump);
use attributes;
use Module::Pluggable;
use Conform::Debug qw(Trace Debug);

=head1  NAME

Conform::PluginLoader

=head1  SYNSOPSIS

use Conform::PluginLoader;

=head1  DESCRIPTION

=cut

=head1   METHODS

=cut

has 'plugins' => (
    is => 'rw',
);

has 'plugin_type' => (
    is => 'rw',
    isa => 'Str',
);

sub get_plugin_type {
    my $self = shift;
    my $type = $self->plugin_type;

    Trace;

    unless ($type) {
        my $class = ref $self;
        ($type = $class) =~ s/^Conform::(\S+)::PluginLoader/$1/;
    }
    return $self->plugin_type($type);
}

requires qw(register);


sub plugin_finder {
    my $self = shift;
    my $type = $self->get_plugin_type;

    Trace;

    my %args = @_;
    my @search_path = ( "Conform::${type}" );
    my @except      = '^Conform::\S+::Plugin';
    my @search_dir  = ();

    if (my $search_path = $args{search_path}) {
        push @search_path,
            ref $search_path eq 'ARRAY'
                ? @$search_path
                : $search_path;
    }

    if (my $except = $args{except}) {
        push @except,
            ref $except eq 'ARRAY'
                ? @$except
                : $except;
    }

    my $except = sprintf "(%s)",
                         join "|", @except;

    $except = qr/$except/;

    if (my $search_dir = $args{search_dir}) {
        push @search_dir,
            ref $search_dir eq 'ARRAY'
                ? @$search_dir
                : $search_dir;
    }

    return new Module::Pluggable::Object
                    search_path => \@search_path,
                    except => $except,
                    require => 0,
                    (scalar @search_dir
                        ? (search_dir => \@search_dir)
                        : ());
}

sub plugin {
    my $self = shift;
    my $class  = ref $self;
    my $source = shift;

    Trace;

    my $plugin = $source;
    my $plugin_type = sprintf "Conform::%s::Plugin", $self->get_plugin_type;
    eval "use $plugin_type;";
    die "$@" if $@;

    $log->debug("Plugging in $plugin_type from $source");

    $source =~ s/::/\//g;
    $source.= '.pm'
        unless $source=~ /\.\S+$/;

    eval {
        my $result = eval <<EOPLUGIN;
require '$source';
EOPLUGIN
        if (my $err = $@) {
            die $err;
        }

        Trace "evaluated %s %s", $source, $result;

        if (UNIVERSAL::isa($plugin, $plugin_type)) {
            (my $name = $source) =~ s!^.*/(\S+)\.(\S+)?!$1!;
            $log->debug("$plugin isa $plugin_type");
            $self->register($plugin_type->new(name => $name));
            return;
        }

        sub _get_type_names {
            my ($type, $field, @list) = @_;

            Trace "%s %s %s", $type, $field, dump(\@list);

            my @names = ();

            ATTR: for my $attr (@list) {
                if ($attr =~ /^\Q$type\E(?:\((\S+)\))?$/) {
                    my $name = $1 || $field;
                    push @names, $name
                        unless grep /^$name$/, @names;
                }
            }

            if ($field =~ s/_\Q$type\E$//) {
                push @names, $field
                    unless grep /^$field$/, @names;
            }

            return @names;
        }

        my $type = $self->get_plugin_type;

        sub _parse_attr {
            my @attr;
            for (@_) {
                /^(\S+?)(?:\(([^)]+)\))?$/ and
                    my ($name, $value) = ($1, $2);
                    push @attr, [ $name, $value ];
            }
            return \@attr;
        }

        no strict 'refs';
        for my $field (keys %{"${plugin}\::"}) {
            next unless defined &{"${plugin}\::${field}"};
            my @attr = attributes::get(\&{"${plugin}\::${field}"});

            for my $name (_get_type_names $type, $field, @attr) {
                $log->debugf("%s::%s is a '%s'", $plugin, $name, $type);

                $self->register(
                        plugin  => $plugin_type,
                        name    => $name,
                        id      => $plugin->getId(),
                        version => $plugin->getVersion() || "0.0",
                        impl    => \&{"${plugin}\::${field}"},
                        attr    => _parse_attr @attr);

            }
        }
    };
    if (my $err = $@) {
        Debug "error $err\n";
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
