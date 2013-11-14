package Conform::Data;
use Moose;

has 'name'    => ( is => 'rw', isa => 'Str' );
has 'version' => ( is => 'rw', isa => 'Str' );
has 'impl'    => ( is => 'rw', isa => 'CodeRef' );
sub id {
    my $self = shift;
    return sprintf "%s-%s", $self->name, $self->version;
}



1;

