package Conform::Role::List;
use strict;
use Mouse::Role;

=head1	NAME

Conform::Role::List

=cut

requires 'add';
requires 'add_all';
requires 'add_list';
#requires 'clear';		# TODO
#requires 'contains';		# TODO
#requires 'contains_all';	# TODO
#requires 'index_of';		# TODO
requires 'remove';
#requires 'retain_all';		# TODO
requires 'size';
requires 'to_array';

1;

__END__

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

# vi: set ts=4 sw=4:
# vi: set expandtab:
