package Conform::Action::Server::File;
use Mouse;
use Conform::Logger qw($log);
use Data::Dump qw(dump);

sub file {
    my ($action, $args) = @_;
    $log->debug("file @{[dump $args]}");

}

1;
# vi: set ts=4 sw=4:
# vi: set expandtab:
