package Conform::Site;
use strict;
use Mouse;
use Safe;
use Data::Dumper;

use Conform::Logger qw($log);

=head1  NAME

Conform::Site

=head1  SYNSOPSIS

use Conform::Site;

=head1  DESCRIPTION

=cut

=head1   METHODS


=head2    uri

=cut

has 'uri',     ( is => 'rw', isa => 'Str' );

=head2    version

=cut

has 'version', ( is => 'rw', isa => 'Str' );

=head2   root

=cut

has 'root',    ( is => 'rw', isa => 'ArrayRef' );

=head2  nodes

=cut

has 'nodes',   ( is => 'rw', isa => 'HashRef' );

=head2  actions

=cut

has 'actions',   ( is => 'rw', isa => 'HashRef' );

=head2  tasks

=cut

has 'tasks',   ( is => 'rw', isa => 'HashRef' );

=head2  vars

=cut

has 'vars',   ( is => 'rw', isa => 'HashRef' );

=head2 classes

=cut

has 'classes',   ( is => 'rw', isa => 'HashRef' );

sub init {
    my $self = shift;
    $log->debugf("%s->init", ref $self);

    my $path = $self->uri;

    my $files = $self->dir_list($path);

    $self->root([ map { s!^.*/!!; $_ } @$files ]);

    $self->_load_nodes;

}

#TODO: site metadata should tell me where to load nodes from 
#TODO: site should also specify who can override what
#TODO: nodes in subdirectories


sub _merge_nodes {
    my $from = shift;
    my $to   = shift;

    $log->debugf("Merging nodes %d -> %d",
                    scalar keys %$from,
                    scalar keys %$to)
                        if $log->is_debug;

    @{$to}{keys %$from} = values %$from;

    $log->debug("Merged = @{[Dumper([keys %$from])]}")
        if $log->is_debug;
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
        $log->debug("Nodes are @{[ Dumper $nodes ]}")
            if $log->is_debug;

        unless (ref $nodes and ref $nodes eq 'HASH') {
            $log->debug("No %nodes expicitly set in $path - checking return value");
            if (ref $return
                    and ref $return  eq 'HASH'
                    and exists $return->{nodes}) {

                $log->debug("@{[ Dumper $return->{nodes} ]}")
                       if $log->is_debug;

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
