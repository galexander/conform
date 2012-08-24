package Conform::Agent;
use strict;
use Carp qw(croak);
use Mouse;
use Conform::Site;
use Conform::Logger qw($log);

=head1  NAME

Conform::Agent

=head1  SYNSOPSIS

use Conform::Agent;

my $agent = Conform::Agent->new
            ( runtime => $runtime, site => $site)


=head1  DESCRIPTION

A B<Conform::Agent> is what manages the conform process for a machine.
It uses a definitions provided by a L<Conform::Site> to execute 
functionality provided by a L<Conform::Runtime>

A Conform::Runtime provides
=over 4

=item   implementation of tasks and actions

=item   implementation of data resolvers

=item   execution and state management

=back

A Conform::Site is responsible for providing the defintion for 
=over 4

=item the runtime that this agent is responsible for

=item required functionality in the form of actions and tasks

=item resources - files, variables, plugins, global variables


=back


=cut


=head1  CONSTRUCTOR

=head2  new

=cut

sub new {
    my $class = shift;
    my $proto = ref ($class) || $class || __PACKAGE__;
    my $self  = $proto->SUPER::new(@_);

    $self->runtime
           or croak "Runtime not specified";

    $self->site
            or croak "site not specified";

    $self->init;

    $self;
}


=head1  METHDOS

=head2  runtime

=cut

has 'runtime' => ( is => 'rw', isa => 'Conform::Runtime');


=head2  site

=cut

has 'site'   =>  ( is => 'rw', isa => 'Conform::Site');


=head1  SEE ALSO



=head1  AUTHOR

Gavin Alexander (gavin.alexander@gmail.com)

=cut

1;

# vi: set ts=4 sw=4:
# vi: set expandtab:
