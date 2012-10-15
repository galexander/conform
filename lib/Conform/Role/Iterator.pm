package Conform::Role::Iterator;
use Mouse::Role;

=head1	NAME

Conform::Util::Iterator

=cut

requires 'has_next';
requires 'next';
requires 'remove';

1;

__END__

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

# vi: set ts=4 sw=4:
# vi: set expandtab:
