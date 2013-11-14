package Conform::Module::Debug;
use strict;
use Conform::Module ();

use base 'Exporter';

our @EXPORT_OK = qw(debug Debug);

sub debug {
    print STDERR @_,"\n" if $Conform::Module::DEBUG;
}

sub Debug {
    debug (@_);
}

1;
