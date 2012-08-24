package Conform::Runtime::Plugin;
use strict;
use Mouse;
use Data::Dumper;
use Scalar::Util qw(refaddr);

my %attrs = ();

=head1  NAME

Conform::Runtime::Plugin

=head1  SYNSOPSIS

use Conform::Runtime::Plugin;

=head1  DESCRIPTION

=cut

sub type {

}

sub MODIFY_CODE_ATTRIBUTES {
    my ($package, $subref, @attrs) = @_;
    $attrs{ refaddr $subref } = \@attrs;
    ();
}

sub FETCH_CODE_ATTRIBUTES {
    my ($package, $subref) = @_;
    my $attrs = $attrs{ refaddr $subref };
    return @{$attrs || [] };
}
        

=head1  SEE ALSO



=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

1;

# vi: set ts=4 sw=4:
# vi: set expandtab:
