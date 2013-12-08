#!/usr/bin/perl -w

use strict;
use Test::More tests => 3;

use_ok 'Conform::Parser';

can_ok 'Conform::Parser',
            qw(parse
               parse_file);



my $test = <<EOSITE;

site "test" {
    class base {

        Test [1,2,3],

        Test [
            { 
                key => value, key => [ 1,2,3 ]
            },
            foo
        ],


        Yum {
            foo => bar
        },

        File_install file {
            key => value

        },
        Network {
            eth0 => {
                ip => "10.1.1.1 some text"

            }
        }
    }
}


EOSITE

my $parser = Conform::Parser->new();

isa_ok $parser, 'Conform::Parser';

my $tree = $parser->parse($test);

use Data::Dumper;
print Dumper($tree);


1;
