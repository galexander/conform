#!/bin/false

package Conform::Util::Deserialize::JSON::XS;

use Mouse;
use namespace::autoclean;

BEGIN {
    $ENV{'PERL_JSON_BACKEND'} = 2; # Always use compiled JSON::XS
}

extends 'Conform::Util::Deserialize::JSON';
use JSON::XS ();

our $VERSION = '0.01';
$VERSION = eval $VERSION;

1;
