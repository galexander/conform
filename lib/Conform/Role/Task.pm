package Conform::Role::Task;
use strict;
use Mouse::Role;

with 'Conform::Role::Directive';

=head1  NAME

Conform::Task

=head1  SYNSOPSIS

use Conform::Task;

Task 'CVS';

use Conform::Action 'File_install';
use Conform::Action 'User';
use Conform::Action 'Package';

Begin {
    Package "cvs";
    User "cvs" => {
        gid => 100,
    };
};

Configure {

};

Execute {

};

End {

};


=head1  DESCRIPTION

=cut

=head1   METHODS


=head2   name

L<Conform::Directive::name>

=head2   desc

L<Conform::Directive::desc>

=cut

=head1  SEE ALSO

=over

=item   *
L<Conform::Role::Directive>

=back

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

1;

# vi: set ts=4 sw=4:
# vi: set expandtab:
