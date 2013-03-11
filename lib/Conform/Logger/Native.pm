package Conform::Logger::Native;
use Mouse;

extends 'Log::Any::Adapter::Stderr';


our @LOG_LEVELS = (qw(
    trace 
    debug 
    info 
    notice
    warn
    error
));

our %LOG_ALIASES = (
    warning => 'warn',
    error => 'fatal',
);

my $LEVEL = 2;

{
    no strict 'refs';
    for (my $i = 0; $i < @LOG_LEVELS; $i++) {
        my $level = $LOG_LEVELS[$i];
        
        my $log_method  = "SUPER\::${level}";
        my $set_level   = "set_${level}";
        my $check_level = "is_${level}";

        my $check = $i;

        *$level = sub {
            my $self = shift;
            if ($self->$check_level()) {
                $self->$log_method(@_);
            }
        };

        *$set_level = sub {
            my $self = shift;
            $LEVEL = $check;
        };

        *$check_level = sub {
            my $self  = shift;
            return $LEVEL <= $check
        };

        if (my $alias = $LOG_ALIASES{$level}) {
            *$alias = sub {
                my $self = shift;
                if ($self->$check_level()) {
                    $self->$log_method(@_);
                }
            };
        }
    }
}


1;
