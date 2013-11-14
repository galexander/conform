package Conform::Action::SCM;
use Moose;
use Data::Dump qw(dump);
use Conform::Logger qw(debug);

use Conform::Action::Plugin;

use Conform::Core::IO qw(:all);
use Carp qw(croak);

our $VERSION = $Conform::VERSION;

sub Conform_module
    : Action(Conform_module)
    : Args(cfg, path, repository, class)
    : Desc(run conform.cfg) {

    my $args = shift;
    my $agent = pop;
    our (%m, $iam);
    no strict 'refs';
    *m = $agent->nodes;
    $iam = $agent->iam;
    our ($_path, $_repository, $_class);
    local ($_path, $_repository, $_class) = (@{ $args }{ qw(path repository class) }); 
    $m{$iam}{ISA}{$_class} = 1;
    chdir $_path;
    debug "executing $_path/conform.cfg for $_repository";
    my $config = $args->{'cfg'};
    my $ret = do $config;
    if (my $err = $@) {
        die "$config: $err" if $err;
    }
    $m{$_class} ||= {};
}

1;
