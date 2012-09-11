#!/bin/false
package Conform::Util::Deserialize::YAML;

use Mouse;

use namespace::autoclean;
use Scalar::Util qw(openhandle);

use YAML::Syck;

our $VERSION = '0.01';
$VERSION = eval $VERSION;

sub execute {
    my $self = shift;
    my $blob = shift;
    my $m    = shift;

    if ( $blob ) {

        my $rbody;

        if(openhandle $blob) {
            seek($blob, 0, 0); # in case something has already read from it
            while ( defined( my $line = <$blob> ) ) {
                $blob .= $line;
            }
        } else {
            $rbody = $blob;
        }

        my $rdata;
        eval { $rdata = Load( $rbody ); };
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
