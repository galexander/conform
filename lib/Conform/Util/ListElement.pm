package Conform::Util::ListElement;
use Mouse;
use Carp qw(croak);

=head1  NAME

Conform::Util::ListElement

=cut

with 'Conform::Role::Comparable';

has 'data' => (
    is       => 'rw',
    isa      => 'Conform::Util::Comparable',
    required => 1,
);

sub equals {
    my $self  = shift;
    my $that = shift;

    my $data = $self->data;

    unless (ref $that) {
        return $data->equals($that);
    }

    if (ref $that and $that->isa(__PACKAGE__)) {
        return $data->equals($that->data);
    }

    if (ref $that and $that->can('equals')) {
        return $data->equals($that);
    }
    
    croak "No way to compare \$this with \$that";
}

1;

__END__

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

# vi: set ts=4 sw=4:
# vi: set expandtab:
