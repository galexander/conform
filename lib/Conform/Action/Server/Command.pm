package Conform::Action::Server::Command;
use Mouse;
use Conform::Logger qw($log);
use IPC::Open3 qw(open3);
use Data::Dump qw(dump);

sub command {
    my ($action, $args) = @_;
    $log->debug("command @{[ dump $args ]}");

    1;
}

1;

# vi: set ts=4 sw=4:
# vi: set expandtab:
