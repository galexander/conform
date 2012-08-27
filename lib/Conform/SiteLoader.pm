package Conform::SiteLoader;
use strict;
use Mouse;
use Carp qw(croak);

use Conform::Logger;

=head1  NAME

Conform::SiteLoader

=head1  SYNSOPSIS

use Conform::SiteLoader;

=head1  DESCRIPTION

=cut

sub load {
    shift if $_[0] eq __PACKAGE__;
    local $_ = shift;
    
    s{^(local|file)://}{} and do {
        return Conform::Site::Local->new(uri => $_);
    };

    croak "$_ not implemented";
}


=head1  SEE ALSO



=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

1;

# vi: set ts=4 sw=4:
# vi: set expandtab:
