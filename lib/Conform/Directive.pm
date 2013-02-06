package Conform::Directive;
use Mouse::Role;

=head1  NAME

Conform::Directive

=head1  SYNOPSIS

package Conform::Task;
use Mouse::Role;

with 'Conform::Directive';

=head1  DESCRIPTION

Conform::Directive is the primary mechanism of extending and
providing functionality for the conform runtime engine.

This is an abstract 'role' that must be extended.

Directives are evaluated during compile time and executed at runtime.

'Dependency/Prereq' and I<version> checking is done at I<compile> time.

This ensures that the correct dependent/prequisite directive is available.

'Require' checking is performed at runtime to ensure that a particular
directive is actually 'run' or 'executed' prior to this directive.

B<All directives SHOULD be idempodent>

=back

=cut

=head1  METHODS

=head2  name

=over

I<name> is often the keyword that describes this directive. 
E.g. 'File' or 'Dir_install' or 'CVS' etc.

=back

=cut

has 'name' => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);


=head2  version

=over
    
I<version> is used by during dependency checks by other
directives to ensure consistency during the compilation phase.

=back

=cut

has 'version' => (
    is  => 'rw',
    isa => 'Str',
);

=head2  desc

=over

I<desc> is a short description for this directive

=back

=cut

has 'desc' => (
    is  => 'rw',
    isa => 'Str',
);

sub execute {
    my $self = shift;
    my $provider = $self->impl;
    if (ref $provider eq 'CODE') {
          # $provider->($self, $self->id, $self->args);
          $provider->($self, @_);
    } else {
        $provider->impl->($self->id, $self->args);
    }
}

######
# TODO
#  prereq   - compile time dependency checking
#  require  - runtime scheduling
#  also     - runtime scheduling - if this directive executes and does something
#  accumulator - accumulate 'directives' @ compile time and @ runtime to be merged 
#  Directive::Compiler? - loads ALL directives by 'type' and generated 'compiled' 'Conform::Directive's?
#  classes for prereq, req? E.g. prereq => [ 'Runtime::Server::Linux::Debian' => 'v6' ]
#  pod parsing for documentation

=head2  prereq

=cut

has 'prereq' => (
    is  => 'rw',
    isa => 'ArrayRef',
);

=head2  'require'

=cut

has 'require' => (
    is  => 'rw',
    isa => 'ArrayRef',
);

has 'impl' => (
    is => 'rw',
);


1;

__END__

=head1  SEE ALSO

=over

=item L<Conform::Task>

=item L<Conform::Action>

=back

=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=head1  COPYRIGHT

Copyright 2012 (Gavin Alexander)

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module

=cut

1;

# vi: set ts=4 sw=4:
# vi: set expandtab:
