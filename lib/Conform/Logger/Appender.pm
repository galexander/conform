package Conform::Logger::Appender;
use Moose;

has 'id' => (
    is => 'ro',
    isa => 'Str',
    required => 1,
);

has 'level' => (
    is => 'rw',
    isa => 'Int',
);

has 'formatter' => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
);

sub get_formatter {
    my $self  = shift;
    my $level = shift;
    my $formatter = $self->formatter->{$level};
    unless (defined $formatter) {
        $formatter = $self->formatter->{'default'} ||= '%m';
    }
    return $formatter;
}

sub clone {
    my $self = shift;
    my %args = @_;
    $args{'id'} ||= $self->id;
    $args{'level'} = $self->level
        unless exists $args{'level'};
    $args{'formatter'} = $self->formatter
        unless exists $args{'formatter'};

    (ref $self)->new(%args);
}

1;
