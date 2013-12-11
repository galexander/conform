package Conform::Parser;
use Moose;
use Parse::RecDescent;
use Data::Dumper;

#$::RD_HINT = 1;
#$::RD_TRACE = 1;

$::RD_AUTOACTION = q{ $item[1] };

sub BUILD {
    my $self = shift;
    $self->parser(new Parse::RecDescent($self->grammar));
    $self;
}

has 'grammar' => (
    is => 'rw',
    isa => 'Str',
    default => <<'EOGRAMMAR'
    program:
        site(s?)

    site:
        'site' name metadata(s? /,/) '{' <leftop: node /,/ node>(s?) '}'
        { [ $thisline, 'site', { name => $item[2], meta => $item[3], data => $item[5] } ] }

    name:
        /[\w.\/-]+/ | /"[\w.\/ =-]+"/

    metadata:
        name ':' name arglist(?)
        { [ $thisline, 'meta', { $item[1] =>  [ $item[3], $item[4] ] } ] }

    arglist:
        '(' arg(s? /,/) ')'
        { $item[2] }

    arg:
        /\w+/ '=' /\w+/
        { $return = { $item[1], $item[3] } }

    comma:
        /,/

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
        /\w+/ name value
        { [ $thisline, 'action', { name => $item[1], id => $item[2], data => $item[3] }  ] }

    block:
        /\w+/ value
        { [ $thisline, 'block',  { name => $item[1], data => $item[2] } ] }

    value:
        hash | list | scalar

    unquoted:
        /[\w\.\-\\\/:]+/

    quoted:
        /(["']).+?\1/

    string:
        quoted | unquoted

    scalar:
        string
        { [ $thisline, 'scalar', $item[1] ] }

    hash:
        '{' hashkv(s? /,/) '}'
        { [ $thisline, 'hash',  $item[2] ] }

    hashkv:
        scalar '=>' value
        { [ $item[1] => $item[3] ] }

    list:
        '[' value(s? /,/) ']'
        { [ $thisline, 'list', $item[2] ] }


    eofile:
        /^\Z/
EOGRAMMAR

);

has 'parser' => (
    is => 'rw',
    isa => 'Parse::RecDescent',
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

    my $parser = $self->parser
                    or die "bad grammar";

    my $tree = $parser->program($text)
            or die "error parse error";

    $self->process($tree);
}

sub _block {
            # line    , type      , data
    return ($_[0]->[0], $_[0]->[1], $_[0]->[2]);
}

sub _normalise($) {
    $_[0] =~ s/^(['"])// && $_[0] =~ s/$1$//;
}

sub process {
    my $self = shift;
    my $tree = shift;
    my @sites = ();
    for my $block (@$tree) {
        my ($line, $type, $section) = _block $block;
        if ($type eq 'site') {
            push @sites, $self->process_site($section);
        }
    }
    return { sites => \@sites };
}

sub process_site {
    my $self     = shift;
    my $block    = shift;

    my $name = $block->{name};
    my $meta = $block->{meta};

    _normalise $name;

    my %site = ();
    my @vars     = ();
    my @classes  = ();
    my @machines = ();

    $site{'.name'} = $name;
    $site{'.meta'} = $meta;

    sub _add_node {
        my ($site, $node) = @_;
        my $node_name = $node->{'.name'};
        my $site_name = $site->{'.name'};
        my $existing = $site->{$node_name};
        if ($existing) {
            warn "node with $node_name already defined for $site_name @ $existing->{'.meta'}{line}";
        } else {
            $site->{$node_name} = $node;
        }
    }

    sub _add_var {
        my ($site, $var) = @_;
        my $var_name  = $var->{'.name'};
        my $site_name = $site->{'.name'};
        my $existing = $site->{".${var_name}"};
        if ($existing) {
            warn "var with $var_name already defined for $site_name @ $existing->{'.meta'}{line}";
        } else {
            $site->{".${var_name}"} = $var;
        }
    }

    my $data = $block->{data} || [];
    for my $block (@$data) {
        my ($line, $type, $section) = _block $block;
        if ($type eq 'class') {
            my $class = $self->process_site_node($section, $block);
            $class->{".type"} = 'class';
            _add_node \%site, $class;
        }
        if ($type eq 'machine') {
            my $machine = $self->process_site_node($section, $block);
            $machine->{".type"} = 'machine';
            _add_node \%site, $machine;
        }
        if ($type eq 'var') {
            my $var = $self->process_site_var($section, $block);
            _add_var \%site, $var;
        }
    }

    return \%site;
}

sub process_site_node {
    my $self   = shift;
    my $block  = shift;
    my $parent = shift;

    my $name = $block->{name};
    my $meta = $block->{meta};

    _normalise $name;

    my %node = ();
    $node{'.name'} = $name;
    $node{'.meta'} = $meta;


    my @blocks  = ();
    my @actions = ();
    my @vars    = ();

    my $data = $block->{data};
    my $tree = $self->parser->nodedef($data)
                    or die "error parsing node ($name)";

    for my $block (@$tree) {
        my ($line, $type, $section) = _block $block;
        my $entry;
        if ($type eq 'action') {
            my $entry = $self->process_site_action($section, $block);
            push @actions, $entry;
        }
        if ($type eq 'block') {
            my $entry = $self->process_site_block($section, $block);
            push @blocks, $entry;
        }
    }

    $node{action} = \@actions;
    $node{blocks} = \@blocks;

    return \%node;
}

sub _process_scalar;
sub _process_list;
sub _process_hash;
sub _process_value;
sub _process_value {
    my $block = shift;
    my ($line, $type, $section) = _block $block;
    if ($type eq 'list') {
        return _process_list $section;
    }
    if ($type eq 'hash') {
        return _process_hash $section;
    }
    if ($type eq 'scalar') {
        if ($section =~ s/^://) {
            return undef if $section eq 'undef';
        }
        _normalise $section;
        return $section;
    }
}

sub _process_list {
    my $block = shift;
    my @list = ();
    for (@$block) {
        push @list, _process_value $_;
    }
    return \@list;
}

sub _process_hash {
    my $block = shift;
    my @list = ();
    for (@$block) {
        push @list, @{_process_list ($_)};
    }
    return  {@list};
}

sub process_site_action {
    my $self  = shift;
    my $block = shift;

    my %action = ();
    my $name = $block->{name};
    my $meta = $block->{meta};
    my $id   = $block->{id};

    _normalise $name;
    _normalise $id;

    $action{'.name'} = $name;
    $action{'.id'}   = $id;

    my $value = _process_value $block->{data};
    $action{'.value'} = $value;

    return \%action;
}

sub process_site_block {
    my $self  = shift;
    my $block = shift;

    my %block = ();
    my $name = $block->{name};
    my $meta = $block->{meta};

    _normalise $name;

    $block{'.name'} = $name;

    my $value = _process_value $block->{data};

    $block{'.value'} = $value;

    return \%block;
}

sub xform {
    my $self  = shift;
    my $block = shift;
    return _process_value $block;
}

1;
