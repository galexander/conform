package Conform::Agent;
use Test::More qw(no_plan);
use strict;
use FindBin;

BEGIN {
    use lib "$FindBin::Bin/../lib";
    use_ok 'Conform::Agent';
}

can_ok 'Conform::Agent', 'runtime';
can_ok 'Conform::Agent', 'site';

use Conform::Logger;
use Conform::Runtime::Server::Linux;
use Conform::SiteLoader;

package Conform::Runtime::Tester;
use Mouse;
extends 'Conform::Runtime';


no Moose;
package main;

#Conform::Logger->set(qw(Stderr));

my $runtime = Conform::Runtime::Tester->new
                ( name => 'test',
                  plugin_search_dirs =>  ["$FindBin::Bin/data/plugins"],
                  plugin_search_paths => ['Runtime'] );


$runtime->load_plugins;

my $uri = "file:///$FindBin::Bin/data/site";
my $site = Conform::SiteLoader->load($uri);


my $agent = Conform::Agent->new(runtime => $runtime, site => $site);


# vi: set ts=4 sw=4:
# vi: set expandtab:
