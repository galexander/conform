#!/bin/false

package Conform::Util::Deserialize::JSON;

use Mouse;

use namespace::autoclean;
use Scalar::Util qw(openhandle);

use JSON;

our $VERSION = '0.01';
$VERSION = eval $VERSION;

sub execute {
    my $self = shift;
    my $blob = shift;
    my $m    = shift;

    my $rbody;

    # could be a string or a FH
    if ( $blob ) {
        if(openhandle $blob) {
            seek($blob, 0, 0); # in case something has already read from it
            while ( defined( my $line = <$blob> ) ) {
                $blob .= $line;
            }
        }
        else {
            $rbody = $blob;
        }
    }

    if ( $rbody ) {
        my $json = JSON->new->utf8;
        my $rdata = eval { $json->decode( $rbody ) };
        if ($@) {
            return $@;
        }
        $m = $rdata;
    } else {
       # $log->debug(
           # 'I would have deserialized, but there was nothing in the body!')
            # if $debug;
    }
    return 1;
}

1;
