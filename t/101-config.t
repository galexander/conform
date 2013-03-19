use strict;
use Test::More tests => 12;
use File::Temp qw(tempdir);
use File::Spec; 
use FindBin;
use Data::Dumper;
use lib "$FindBin::Bin/../lib";

use_ok 'Conform::Config';
is ($Conform::Config::VERSION, $Conform::VERSION, 'version ok');

can_ok 'Conform::Config', 'set';
can_ok 'Conform::Config', 'get_config';

my $perl_config = {
    'Conform::Test::Config' => {
        param => 'value'
    },

    'foo' => {
        bar => 'baz',
    }
};

Conform::Config->set($perl_config);

is_deeply(Conform::Config->get_config(),
          { param => 'value' }, 'get_config OK');
is_deeply(Conform::Config->get_config(category => 'foo'),
          { bar => 'baz' }, 'get_config OK');


# reset
Conform::Config->set({});
is_deeply(Conform::Config->get_config(), {}, 'reset OK');
is_deeply(Conform::Config->get_config(category => 'foo'), {}, "reset 'foo' OK");


my $dir = tempdir(CLEANUP => 1);
my $perl_config_file = File::Spec->catfile($dir, "config.perl");

$Data::Dumper::Terse++;

open my $fh, '>', "$perl_config_file"
    or die "$!";

$perl_config->{'Conform::Test::Config'}->{param2} = 'value2';
$perl_config->{foo}->{param} = 'value';

print $fh <<EOPERL;
@{[Dumper($perl_config)]};
EOPERL
close $fh;

Conform::Config->set('files' => [ "$perl_config_file" ]);

is_deeply(Conform::Config->get_config(),
          { param => 'value', 'param2' => 'value2' }, 'get_config (perl) OK');
is_deeply(Conform::Config->get_config(category => 'foo'),
          { bar => 'baz', param => 'value' }, 'get_config (perl) OK');

SKIP : {
    eval "use Config::Tiny;";
    skip "Config::Tiny not available", 3 if $@;

    my $ini_config_file = File::Spec->catfile($dir, "config.ini");
    open my $fh, '>', $ini_config_file
        or die "$!";
    print $fh <<EOINI;
[foo]
bar=baz

[Conform::Test::Config]
param=value

EOINI
    close $fh;

    Conform::Config->set('files' => [ "$ini_config_file" ]);

    is_deeply(Conform::Config->get_config(),
              { param => 'value', }, 'get_config (ini) OK');
    is_deeply(Conform::Config->get_config(category => 'foo'),
              { bar => 'baz', }, 'get_config (ini) OK');


}

# vi: set ts=4 sw=4:
# vi: set expandtab:
