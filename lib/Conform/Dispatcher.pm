#!/bin/false
package Conform::Dispatcher;

use strict;
use warnings;

our $VERSION = '0.1';    # VERSION

my %reg;

=head2 process

 process \%hash

This function scans through the top level of the provided hash, looks for
matches in the action registry and enqueues them.

=cut

sub process {

    my $arg = shift;

    for my $k (sort keys %$arg) {
        $reg->{$k}->enqueue($arg->{$k})
            if $register{$k};
    }

}

=head2 register

 register 'Key_name' => $obj;

Registers a new key handler object in to the registry. Then automatically
sweeps the configuration for unprocessed keys and enqueues them.

=cut

sub register {

    my ($k, $v) = @_;

    $reg{$k} = $v;

    #FIXME: we should now sweep the entire config hash for unprocessed keys

}

1
