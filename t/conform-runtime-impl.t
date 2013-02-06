#!/usr/bin/perl
use Test::More qw(no_plan);
use strict;
use FindBin;

BEGIN {
    use lib "$FindBin::Bin/../lib/";
    use_ok 'Conform::Runtime::Server::Linux';
    use Conform::Logger qw($log);

}

package Conform::Runtime::Server::Linux::Test;
use Mouse;
extends 'Conform::Runtime::Server::Linux';

sub os_distro           { 'os_distro'; }
sub os_distro_version   { 'os_distro_version' };


package main;

Conform::Logger->set('Stderr');

my $rt = Conform::Runtime::Server::Linux::Test->new();

$rt->boot();

#ok $rt->isa('Conform::Runtime');
#ok $rt->isa('Conform::Runtime::Server');
#ok $rt->isa('Conform::Runtime::Server::Linux');


# vi: set ts=4 sw=4:
# vi: set expandtab:
