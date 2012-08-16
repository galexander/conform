package Conform::Action;
use Test::More qw(no_plan);
use Test::Trap;
use strict;
use FindBin;

BEGIN {
    use lib "$FindBin::Bin/../lib";
    use_ok 'Conform::Action';
}

can_ok 'Conform::Action', 'new';
can_ok 'Conform::Action', 'id';
can_ok 'Conform::Action', 'name';
can_ok 'Conform::Action', 'desc';
can_ok 'Conform::Action', 'execute';

my $action;

##
# Test failure cases for constructor

trap {
    $action = Conform::Action->new()
};
ok !defined $action, 'action constructor returned undef';
like $trap->die(), qr/Attribute \(\S+\) is required/, 'action constructor died OK';

##
# Test constructor without code

$action = Conform::Action->new(name => 'test');

ok   $action,                'action constructor returned ok';
is   $action->name,          'test', 'action->name set correctly';
ok   !defined $action->code, 'action->code not defined';

trap {
     $action->execute;
};
like $trap->stderr, qr/not implemented/, 'action->execute ok';

##
# TODO: test constructor with invalid name (I.e. not a Str)
#           still figuring out how this will work from 
#           the perspective of a caller - need a contextual msg
##

##
# Test constructor with invalid code ref

trap {
    undef $action;
    $action = Conform::Action->new(name => 'test', code => "not valid");
};

ok !defined $action,   'action constructor returned undef';
ok defined $trap->die, 'action died ok';
like $trap->die(), qr/Validation failed/, 'action died with parameter validation error';

my $data = { };
my @action_data = ("foo" => { param => 'value' });

trap {
    $action = Conform::Action->new(name => 'test',
        code => sub {
            my $self = shift;
            $data->{'action'} = $self;
            $data->{'random'} = 'foo';
            $data->{'vars'}   = \@_;

            print STDERR "STDERR ok";
            print STDOUT "STDOUT ok";

        });

    $action->execute(@action_data);

};

ok defined $action,             'action is defined';
ok defined $data->{'action'},   'action is defined from "execute"';
is $data->{'action'}, $action,  'action passed to "execute" successfully';
is $data->{'random'}, 'foo',    'action set some data correctly';
is_deeply $data->{'vars'}, \@action_data, 'action data passed correctly from "execute"';
is $trap->stderr, "STDERR ok", '"execute" wrote to stderr OK';
is $trap->stdout, "STDOUT ok", '"execute" wrote to stdout OK';

# vi: set ts=4 sw=4:
# vi: set expandtab:
