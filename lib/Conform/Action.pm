package Conform::Action;
use Mouse;
use Conform::Logger qw($log);
use Data::Dump qw(dump);
use attributes;

with 'Conform::Directive';

=head1  NAME

Conform::Action

=head1  SYNSOPSIS

use Conform::Action;

=head1  DESCRIPTION

=cut

=head1   METHODS

=head2   name

=cut

=head2   desc

=cut

has 'id' => (
    is => 'rw',
    isa => 'Str',
);

has 'complete' => (
    is => 'rw',
    isa => 'Bool',
);

has 'dependencies' => (
    is => 'rw',
    isa => 'ArrayRef',
    default => sub { [] },
);

sub BUILD {
    my $self = shift;
    $self;
}

sub satisfies {
    my $self = shift;
    my $dependency = shift;
    my $checked = 0;
    if (exists $dependency->{name}) {
        $checked++; 
        if ($self->name ne $dependency->{name}) {
            return 0;
        }
    }
    if (exists $dependency->{id}) {
        $checked++;
        if (defined $self->id) {
            if ($self->id ne $dependency->{id}) {
                return 0;
            }
        }
    }

    return $checked;
}


=head1  SEE ALSO

L<Conform::Directive>

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

1;

# vi: set ts=4 sw=4:
# vi: set expandtab:
