#!/bin/false
package Conform::Actions;

use strict;
use warnings;
use Module::Pluggable::Object;

sub import {

    my $finder = Module::Pluggable::Object->new(
        search_path => [ 'Conform::Action' ],
        instantiate => 'registration',
    );

}

# thats it!

1

