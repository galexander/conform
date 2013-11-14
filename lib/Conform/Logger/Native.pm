package Conform::Logger::Native;
use Moose;
use strict;

extends 'Log::Any::Adapter::Base';
use Log::Any::Adapter::Util qw(make_method);


=head1  NAME

Conform::Logger::Native

=head1 SYNOPSIS

 use Conform::Logger::Native;
 
=cut

=head1 DESCRIPTION

=cut

use constant LOG_LEVEL_DEBUG        => 0;
use constant LOG_LEVEL_NOTICE       => 1;
use constant LOG_LEVEL_WARNING      => 2;
use constant LOG_LEVEL_ERROR        => 3;
use constant LOG_LEVEL_CRITICAL     => 4;
use constant LOG_LEVEL_ALERT        => 5;
use constant LOG_LEVEL_EMERGENCY    => 6;

my %LOG_LEVELS = (
    'DEBUG'     => LOG_LEVEL_DEBUG,
    'NOTICE'    => LOG_LEVEL_NOTICE,
    'WARNING'   => LOG_LEVEL_WARNING,
    'ERROR'     => LOG_LEVEL_ERROR,
    'CRITICAL'  => LOG_LEVEL_CRITICAL,
    'ALERT'     => LOG_LEVEL_ALERT,
    'EMERGENCY' => LOG_LEVEL_EMERGENCY,
);

sub LEVEL {
    my $lvl_name = shift;
    my $lvl = exists $LOG_LEVELS{uc $lvl_name}
                ? $LOG_LEVELS{uc $lvl_name}
                : LOG_LEVEL_ERROR;

    return $lvl;
}

has 'level' => (
    is => 'rw',
    required => 1,
    default => sub { LEVEL('NOTICE') },
);

# Create logging methods: debug, info, etc.
#
foreach my $method ( Log::Any->logging_methods() ) {
    make_method($method, 
        sub { 
            my $self = shift; 
            my $msg = shift; 
            #print STDERR "@{[ uc $method ]}:$msg\n" if $msg;
    });
}

# Create detection methods: is_debug, is_info, etc.
#
foreach my $method ( Log::Any->detection_methods() ) {
    make_method($method, sub {
        my $self = shift;
        $method =~ s/^is_//;
        return ($self->level || LEVEL('DEBUG')) >= LEVEL($method);
    });
}



1;

# vi: set ts=4 sw=4:
# vi: set expandtab:
