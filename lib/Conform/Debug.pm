package Conform::Debug;
use base 'Exporter';
use strict;

our @EXPORT_OK = (qw(Debug Trace));

our $DEBUG = 0;
our $TRACE = 0;

sub _msg {
    return unless ${shift()};
    my $type = shift;
    my $ctx  = shift;

    if (@_ >= 2) {
        print sprintf "[%s %s] @{[shift]}\n",
            $type,
            $ctx,
            @_;
    } else {
        printf "[%s %s] %s\n",
            $type,
            $ctx,
            @_;
    }
}

sub Debug {
    _msg \$DEBUG, 'DEBUG', (caller)[0], @_;
}

sub Trace {
    _msg \$TRACE, 'TRACE', (caller)[0], @_;

}




1;
