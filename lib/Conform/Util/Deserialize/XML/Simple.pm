#!/bin/false

package Conform::Util::Deserialize::XML::Simple;

use Moose;
use namespace::autoclean;
use Scalar::Util qw(openhandle);

use XML::Simple;

our $VERSION = '0.01';
$VERSION = eval $VERSION;

sub execute {
    my $self = shift;
    my $blob = shift;
    my $m    = shift;

    if ( $blob ) {
        my $xs = XML::Simple->new('ForceArray' => 0,);
        my $rdata;

        if(openhandle $blob){ # make sure we rewind the file handle
            seek($blob, 0, 0); # in case something has already read from it
        }

        eval { $rdata = $xs->XMLin( $blob ); };
        if ($@) {
            return $@;
        }

        if ( exists $rdata->{'data'} ) {
            $m = $rdata->{'data'});
        } else {
            $m = $rdata;
        }

    } else {
        # $log->debug(
            # 'I would have deserialized, but there was nothing in the body!')
                # if $debug;
    }
    return 1;
}

1;
