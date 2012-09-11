package Conform::Util::LinkedListIterator;
use Mouse::Role;

=head1	NAME

Conform::Util::LinkedListIterator

=cut

with 'Conform::Util::ListIterator';


=head1  CONSTRUCTOR

=head2  new

=cut

sub BUILD {
    my $self = shift;
    $self->index(\0);
}

has 'list' => (
    is  => 'ro',
    isa => 'ArrayRef',
);

has 'index' => (
    is  => 'ro',
);

=head1	OBJECT METHODS

=cut

=head2  has_next

=cut

sub has_next {
    my $self = shift;
    my $idx  = $self->index;
    my $list = $self->list;

    return $$idx < @{$list};
}

=head2  has_previous

=cut

sub has_previous {
    my $self = shift;
    my $idx  = $self->index;
    my $list = $self->list;

    
    return $$idx > 0;
}

=head2  next

=cut

sub next {
    my $self = shift;
    my $idx  = $self->index;
    my $list = $self->list;

    return $list->[$$idx++];

}

=head2  previous

=cut

sub previous {
    my $self = shift;
    my $idx  = $self->index;
    my $list = $self->list;

    return $list->[$$idx--];
}

=head2  remove

=cut

sub remove {
    my $self = shift;
    my $idx  = $self->index;
    my $list = $self->list;

    splice @{$list}, $$idx, 1;
}

=head2  insert

=cut

sub insert {
    my $self = shift;
    my $node = shift;
    my $idx  = $self->index;
    my $list = $self->list;

    
    splice @{$self->list}, $idx, 0, $node;
}


1;

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

# vi: set ts=4 sw=4:
# vi: set expandtab:
