package Conform::Task::Common;

use Conform::Task::Plugin;

sub Hostname
    :Task
    :Prio(LAST) {

    printf "Setting hostname to @{[ i_isa 'Hostname' ]}\n";

}

1;
