package Conform::Site;
use strict;
use Moose;
use Safe;
use Carp qw(croak);
use Data::Dump qw(dump);

use Conform::Logger qw($log trace debug notice fatal);

=head1  NAME

Conform::Site

=head1  SYNSOPSIS

use Conform::Site;

=head1  DESCRIPTION

=cut

=head1   ACCESSOR METHODS

=head2    uri

=cut

has 'uri' => (
    is  => 'rw',
    isa => 'Str'
);

=head2    version

=cut

has 'version' => (
    is  => 'rw',
    isa => 'Str'
);

=head2   root

=cut

has 'root' => (
    is  => 'rw',
    isa => 'ArrayRef'
);

=head2  nodes

=cut

has 'nodes' => (
    is  => 'rw',
    isa => 'HashRef'
);

sub BUILD {
    my $self = shift;
    $self->init;
}

sub init {
    my $self = shift;
    debug "%s->init", ref $self;

    if (my $path = $self->uri) {
        my $path = $self->uri;
        my $files = $self->dir_list($path);
        $self->root([ map { s!^.*/!!; $_ } @$files ]);
        $self->_load_nodes;
    }
}

=head2  traverse

=cut

sub _traverse;
sub _traverse {
    my ($nodes, $key, $code, $seen) = @_;

    $seen ||= {};

    if($seen->{$key}++) {
        $log->debug("seen key $key");
        return;
    }

    my $node = $nodes->{$key};
    if(!defined $node) {
        debug "key ($key) not found";
        return;
    }

    my $isa = $node->{ISA};
    if (defined $isa) {
        for my $class ((ref $isa eq 'HASH')
                        ? (sort keys %$isa)
                        : (ref $isa eq 'ARRAY')
                            ? (sort @$isa)
                            : ($isa)) {

            _traverse $nodes, $class, $code, $seen;

        }
    }

    $code->($key, $node);
    
}

sub traverse;
sub traverse {
    my $self    = shift;
    my $from    = shift;
    my $code    = shift;

    my $nodes   = $self->nodes;
    
    if (defined $from) {
        croak "$from not found in \$site->@{[$self->uri]}"
            unless exists $nodes->{$from};

        debug "Traversing nodes from $from";
        _traverse $nodes, $from, $code, {};

    } else {
        debug "Traversing ALL nodes";
        for my $node (keys %$nodes) {
            $self->traverse($from, $code);
        }
    }

}


#TODO: site metadata should tell me where to load nodes from 
#TODO: site should also specify who can override what
#TODO: nodes in subdirectories


sub _merge_nodes {
    my $from = shift;
    my $to   = shift;

    debug "Merging nodes %d -> %d",
          scalar keys %$from,
          scalar keys %$to;

    @{$to}{keys %$from} = values %$from;

    debug "Merged = @{[dump([keys %$from])]}";
}

sub _load_nodes {
    my $self = shift;
    my $root = $self->root;

    my %nodes = ();

    for my $file (grep /^(machines|nodes)\.(cfg|yml|json|ini|cfm)$/, @$root) {
        $log->debug("Loading node definitions from @{[$self->uri]}/$file");
        my $nodes = $self->_load_nodes_perl($file)
            if $file =~ /\.cfg$/;

        if ($nodes) {
            _merge_nodes $nodes => \%nodes
        }
    }

    $self->nodes(\%nodes);
}

sub _load_nodes_perl {
    my $self = shift;
    my $file = shift;
    my $path = sprintf "%s/%s", $self->uri, $file;
        

    my $code = eval { $self->file_read($path) };
    if ($@) {
        $log->errorf("Error loading node definitions from %s: %s", $path, $@);
        return undef
    }
                
    if ($code) {
        my $safe = Safe->new();
        my $return = $safe->reval($code, my $strict = 1);
        if ($@) {
            $log->errorf("Error loading node definitions from %s: %s", $path, $@); 
            return undef;
        }

        no strict 'refs';
        my $ns = $safe->root;
        my $nodes = \%{"${ns}\::nodes"};
        debug "Nodes are @{[ dump $nodes ]}";

        unless (ref $nodes and ref $nodes eq 'HASH') {
            debug "No %nodes expicitly set in $path - checking return value";
            if (ref $return
                    and ref $return  eq 'HASH'
                    and exists $return->{nodes}) {

                debug "@{[ dump $return->{nodes} ]}";

                return $return->{nodes};
            }
        }

        return $nodes;
    }
    return undef;
}


=head1  SEE ALSO

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

1;

# vi: set ts=4 sw=4:
# vi: set expandtab:

