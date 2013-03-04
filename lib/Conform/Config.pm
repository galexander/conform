package Conform::Config;
use Mouse;

=head1  NAME

Conform::Config

=head1  SYNSOPSIS

use Conform::Config;

=head1  DESCRIPTION

Conform::Config is a configuration loader for conform.
Its a singleton that loads configuration for a package,
class, or object.

Conform::Config extends L<Config::Any> for pluggable configuration
file formats.

=cut

extends 'Config::Any';

use Hash::Merge qw(merge);
use Storable qw(dclone);

my $root = undef;

=head1 CLASS METHODS

=cut

=head2 set (@args)

    Conform::Config->set({ foo => 'bar' });
    Conform::Config->set('/path/to/file.perl', '/path/to/file.ini');

=cut

sub set {
    my $package = shift;
    if (ref $_[0] && ref $_[0] eq 'HASH') {
        $root = shift @_;
    } else {
use Data::Dumper;
print Dumper(\@_);
        my $cfg = $package->SUPER::load_files({@_, use_ext => 1});
        $root = { };
        for (@$cfg) {
            my ($file, $config) = %$_;
            $root = merge ($root, $config);
        }
    }
}

=head2 get_config(%args)

    Conform::Config->get_config();
    Conform::Config->get_config(category => 'foo');

=cut

sub get_config {
    my $package = shift;
    return { }
        unless defined $root;

    my %args = @_;
    my $caller = $args{'category'}
                  || $args{'for'}
                  || caller;

    return { }
        unless exists $root->{$caller}
          and defined $root->{$caller};

    return dclone ($root->{$caller} || {});
}

=head1  SEE ALSO

L<Config::Any>

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

1;

# vi: set ts=4 sw=4:
# vi: set expandtab:
