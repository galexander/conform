package Conform::Parser;
use Moose;
use Parse::RecDescent;

my $grammar = q{
    program:
        site(s?)

    site:
        'site' name metadata(s? /,/) '{' node(s? /,/) '}'
        { [ $thisline, 'site', { name => $item[2], meta => $item[3], data => $item[5] } ] }

    name:
        /[\w.\/=-]+/ | /"[\w.\/ =-]+"/

    metadata:
        name ':' name arglist(?)
        { [ $thisline, 'meta', { $item[1] =>  [ $item[3], $item[4] ] } ] }

    arglist:
        '(' arg(s? /,/) ')'
        { $item[2] }

    arg:
        /\w+/ '=' /\w+/
        { $return = { $item[1], $item[3] } }

    node:
        nodetype name metadata(s? /,/) text
        { [ $thisline, $item[1], { name => $item[2], meta => $item[3], data => $item[4] } ] }

    nodetype:
        'class' | 'machine'

    text:
        { extract_bracketed($text, '{ }') }

    nodedef:
        '{' nodeconf(s? /,/) '}'
        { $item[2] }

    nodeconf:
        action | block
        { $item[1] }

    action:
        /\w+/ /\w+/ value
        { [ $thisline, 'action', { name => $item[1], id => $item[2], data => $item[3] }  ] }

    block:
        /\w+/ value
        { [ $thisline, 'block',  { name => $item[1], data => $item[2] } ] }

    value:
        hash | list | simple

    simple:
        /"[^"]+"/ | /\w+/
        { [ 'scalar', $item[1] ] }

    hash:
        '{' hashkv(s? /,/) '}'
        { [ 'hash',  $item[2] ] }

    hashkv:
        simple '=>' value
        { [ $item[1] => $item[3] ] }

    list:
        '[' value(s? /,/) ']'
        { [ 'list', $item[2] ] }


    eofile:
        /^\Z/
};

$::RD_AUTOACTION = q{ $item[1] };

sub BUILD {
    my $self = shift;
    $self->grammar($grammar);
    $self;
}

has 'grammar' => (
    is => 'rw',
    isa => 'Str',
);

sub parse_file {
    my $self = shift;
    my $file = shift;

    open my $fh, '<', $file
        or die "open $file $!";

    my $text = do { local $/; <$fh> };

    close $fh;

    $self->parse($text);
}

sub parse {
    my $self = shift;
    my $text = shift;

    my $parser = Parse::RecDescent->new($self->grammar)
                    or die "bad grammar";

    my $tree = $parser->program($text);
    $self->process($tree);
}

sub process {
    my $self = shift;
    my $tree = shift;
    my @processed;
    for my $block (@$tree) {
        my ($line, $type, $data) = ($block->[0], $block->[1], $block->[2]);
        if ($type eq 'site') {
            push @processed, $self->process_site($data);
        }
        if ($type eq 'class') {
            push @processed, $self->process_site_node($block, $data);
        }
        if ($type eq 'machine') {
            push @processed, $self->process_site_node($block, $data);
        }
    }
    return \@processed;
}

sub process_site {
    my $self  = shift;
    my $block = shift;
    my $site;
    my $name = $block->{name};
    my $meta = $block->{meta} || [];
    my $data = $block->{data} || [];

    my $nodes = $self->process($data);

    return  { name => $name, meta => $meta, nodes => $nodes };
}

sub process_site_node {
    my $self  = shift;
    my $parent = shift;
    my ($line, $type, $block) = ($parent->[0], $parent->[1], $parent->[2]);
    my $name = $block->{name};
    my $meta = $block->{meta};
    my $data = $block->{data};

    my $parser = Parse::RecDescent->new($grammar)
                    or die "grammar error";

    my $tree = $parser->nodedef($data)
                    or die "error parsing node($name) @ line $line";


    return { type => $type, name => $name, meta => $meta, data => $tree };
    
}


1;
