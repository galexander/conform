package Conform::Role::Queue;
use Mouse::Role;

=head1	NAME

Conform::Util::Queue

=cut

requires 'enqueue';
requires 'dequeue';

1;

__END__

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

# vi: set ts=4 sw=4:
# vi: set expandtab:
