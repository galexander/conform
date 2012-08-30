#!/bin/false
package Conform::Util::Deserialize::Callback;

use Mouse;

use namespace::autoclean;
use Scalar::Util qw(openhandle);

our $VERSION = '0.01';
$VERSION = eval $VERSION;

sub execute {
    my $self = shift;
    my $blob = shift;
    my $m    = shift;
    my $code = shift;

    my $rbody;

    # could be a string or a FH
    if ( $blob ) {
        if(openhandle $blob) {
            seek($blob, 0, 0); # in case something has already read from it
            while ( defined( my $line = <$blob> ) ) {
                $rbody .= $line;
            }
        } else {
            $rbody = $blob;
        }
    }

    if ( $rbody ) {
        # FIXME, $code should be checked to be a subref
        my $rdata = eval { $code->( $rbody ) };
        if ($@) {
            return $@;
        }
        $m = $rdata;
    } else {
       # $log->debug(
           # 'I would have deserialized, but there was nothing in the body!')
            #if $debug;
    }
    return 1;
}

1;

