#!/bin/false

=encoding utf8

=head1 NAME

Conform::Core - Conform Core host configuration functions

=head1 SYNOPSIS

    use Conform::Core;

    $Conform::Core::debug          = $debug;
    $Conform::Core::safe_mode      = $safe_mode;
    $Conform::Core::safe_write_msg = $message;
    $log_messages = $Conform::Core::log_messages;

    debug @messages;
    note  @messages;
    warn  @messages;
    die   @messages;

    $result  = action $message => \&code, @args;
    $result  = safe   \&code, @args;


    my $obj = Conform::Core->new( hash => \%m, iam => 'host.name' );

    use Conform::Core qw(:all :deprecated);

    @values   = comma_or_arrayref @csvs;

    $value    = validate $schema, $new, $old, @keys;

    $is_class = i_isa_class $thing;
    $is_host  = i_isa_host  $thing;

    @hosts    = type_list      \%m, @tags;

    $value    = i_isa          \%m, $host, $tag;
    $values   = i_isa_fetchall \%m, $host, $tag;
    @values   = i_isa_fetchall \%m, $host, $tag;
    $value    = i_isa_mergeall \%m, $host, $tag, $behaviour;
    $value    = i_isa_merge    \%m, $host, $tag, $schema, $default;

    @ints     = ints_on_host   \%m, $host;
    $ip       = ips_on_host    \%m, $host;
    @ips      = ips_on_host    \%m, $host;

    # Deprecated functions (only imported with :deprecated)

    $groups   = build_netgroups;
    @ips      = expand_netgroup \%groups, $group;

=head1 DESCRIPTION

The Conform::Core module contains functions for extracting and validating
host configurations from the Conform::Core common configuration files C<machines> and
C<routers.cfg>.

=cut

package Conform::Core;

use strict;

use Carp;
use Conform::Debug qw(Debug);
use Conform::Core::Netgroups;

use Hash::Merge ();

use base qw( Exporter );
use vars qw( $VERSION %EXPORT_TAGS @EXPORT_OK );
$VERSION = (qw$Revision: 1.54 $)[1];

%EXPORT_TAGS = (
    all => [
        qw(
          action timeout safe note debug lines_prefix $log_messages
          $debug $safe_mode $safe_write_msg
          comma_or_arrayref
          validate
          type_list i_isa_class i_isa_host
          i_isa i_isa_fetchall i_isa_mergeall i_isa_merge
          ints_on_host ips_on_host
          )
    ],
    deprecated => [
        qw(
          build_netgroups expand_netgroup
          )
    ],
);

Exporter::export_ok_tags( keys %EXPORT_TAGS );

my %deprecated;

sub _deprecated {
    my $key = shift;
    return if $deprecated{$key};
    carp @_;
    $deprecated{$key}++;
}

=head1 VARIABLES

=over

=item B<$Conform::Core::IO::File::safe_mode>

    $Conform::Core::IO::File::safe_mode = $safe_mode;

When set, potentionally dangerous actions are not performed. By default, safe
mode is I<not> enabled.

=item B<$Conform::Core::IO::File::safe_write_msg>

    $Conform::Core::IO::File::safe_write_msg = $message;

The log message used when checking files into RCS.

=back

=cut

our $safe_mode      = 0;
our $safe_write_msg = "Changed by $0";
our $debug          = $Conform::Debug::DEBUG;
our $log_messages   = "";

sub debug { Debug @_ }
sub note  { Debug "Note: ", @_ }
sub lines_prefix { "" }

=head1 FUNCTIONS

=over

=item B<action>

    $result = action $message => \&code, @args;

Logs the supplied message (using B<note>) if it is not empty, then, if safe mode
is not enabled, executes the code reference with the given parameters. The code
reference is evaluated in the context (void, scalar, or list) in which B<action>
was called.

In safe mode, the integer 1 is returned, otherwise the return value is that
of the code reference.

=cut

sub action {
    my ( $message, $code, @args ) = @_;
    $code and ref $code eq 'CODE'
      or croak 'Usage: Conform::Core::IO::File::action($message, \&code, @args)';

    if ($safe_mode) {
        note "SKIPPING: $message\n" if $message;
        return 1;
    }
    else {
        note "$message\n" if $message;
        return $code->(@args);
    }
}

=item B<safe>

    $result = safe \&code, @args;

If safe mode is not enabled executes the code reference with the given
parameters.

Exactly equivalent to:

    $result = action '' => \&code, @args;

=cut

sub safe {
    $_[0] and ref $_[0] eq 'CODE'
      or croak 'Usage: Conform::Core::IO::File::safe(\&code, @args)';
    action '' => @_;
}

sub timeout {
    my ( $timeout, $code ) = @_;
    unless ($timeout) {
        $code->();
        return 0;
    }

    my $alarm = alarm 0;
    my $err   = do {
        local $SIG{ALRM} = sub { die "alarm\n" };
        alarm $timeout;
        eval { $code->() };
        $@;
    };
    alarm $alarm;
    if ($err) {
        die $err unless $err eq "alarm\n";
        undef $@;
        return 1;
    }

    return 0
}

=head1 OBJECT INTERFACE

The object interface allows you save some time in writing out the whole
function names, or importing functions in to the local name space, or
providing the same two arguments over and over.

Once the object is created with new(), all the B<FUNCTIONS> are available
as object methods - but without \%m and $host arguments (ie the first
two arguments). Functions that dont require these arguments function as
normal, just as an object method.

Deprecated functions wont work.

=over

=item B<new>

Arguments for new are ...

  hash => \%hash
  host  => 'host.name'

Which are equivalent to the first two arguments of all B<FUNCTIONS>.

=back

=cut

sub new {

    my $p    = shift;
    my %args = @_;
    my $c    = ref($p) || $p;
    my $self = bless {}, $c;

    croak 'Please provide a "hash" argument to create the object'
      unless $args{hash};

    croak '"hash" argument must be a hashref'
      unless ref $args{hash} and ref $args{hash} eq 'HASH';

    croak 'Please provide a "host" argument to create the object'
      unless $args{host};

    croak '"host" argument must be a scalar'
      if ref $args{host};

    $self->_init(%args);

    return $self

}

=over

=item B<iam>

Only relevant for objects. Sets the 'host' property of the object to the
argument (if provided). Returns the internal 'host' property.

  $iam = $obj->iam();
  $iam = $obj->iam('new.host.name');

=back

=cut

sub iam {

    my ( $self, $new ) = @_;

    die 'the iam function is only relevant when used with an object'
      unless ref $self and ref $self eq __PACKAGE__;

    if ($new) {

        die 'new host arguments must be a scalar'
          if ref $new;

        $self->{host} = $new;

    }

    return $self->{host}

}

sub _init {

    my $self = shift;
    my %args = @_;

    # copy the hash, so we dont change it accidentally
    $self->{m} = { %{ $args{hash} } };

    $self->{host} = $args{host};

    return 1

}

=head1 FUNCTIONS

=over

=item B<comma_or_arrayref>

    @values = comma_or_arrayref @csvs;

Returns a flattened list of values. Each element of C<@csvs> must be a
comma-separated values or an array reference containing comma-separated values.

=cut

sub comma_or_arrayref {

    if ( @_ and ref $_[0] and ref $_[0] eq __PACKAGE__ ) {
        shift;
    }

    grep { defined $_ }
      map { ref $_ ? $_ : defined $_ ? split /\s*,\s*/, $_ : () }
      map { ref $_ eq 'ARRAY' ? @$_ : $_ } @_;
}

=item B<validate>

    $value = validate $schema, $new, $old, @keys;

Validates C<$new> according to C<$schema> and merges it with C<$old>, and
returns the resulting value. Dies if validation is unsuccessful.

C<$schema> specifies what kind of validation is performed on C<$new> and how
it should be merged with C<$old>:

=over

=item *

If C<$schema> is a hash reference, then C<$new> must be a hash reference.
C<$old> must be undefined or a hash reference.

For each key C<$key> in C<%$schema>:

=over

=item *

If C<< $new->{$key} >> does not exist, no action is taken.

=item *

Else if C<< $new->{$key} >> is undefined, C<< $old->{$key} >> is deleted.

=item *

Otherwise, C<< $new->{$key} >> is validated against C<< $schema->{$key} >>
and merged with C<< $old->{key} >>. In other words, this recursively calls:

    $value = validate
                 $schema->{$key},
                 $new->{$key}, $old->{$key},
                 @keys, $key;

Then C<$value> is assigned to C<< $old->{$key} >>.

=back

The final state of C<$old> is returned as the merged value. Note that $old is
modified in place (unless it is undef, in which case a new hash is created).

=item *

If C<$schema> is an array reference, then C<$new> must be an array reference
such that the number of elements in C<@$new> is evenly divisible by the number
of entries in C<@$schema>. C<$old> must be undefined or an array reference.

Each set of n elements in C<@$new> is recursively validated against the n
schema elements in C<@$schema>. The results are I<appended> to C<@$old>.

The final state of C<$old> is returned as the merged value. Note that $old is
modified in place (unless it is undef, in which case a new array is created).

=item *

If C<$schema> is a compiled regular expression, then C<$new> must match the
regular expression. It is not merged with C<$old>; the returned value is
simply C<$new>.

=item *

If C<$schema> is a code reference, it is called with arguments C<$new>, C<$old>
and C<@keys>. The value returned by the code reference is returned by
C<validate> itself.

=item *

If C<$schema> is one of the terminals "any", "scalar", "integer", "number",
"nonempty" or "ipaddr", an appropriate validation is performed on C<$new>. An
exception is thrown with die() if validation fails, otherwise C<$new> is
returned. C<$old> is not used in these cases: the value returned is always C<$new>.

The effect of the various terminals is as follows.

=over

=item I<any>

No validation. Always returns C<$new> no matter what value it holds.

=item I<scalar>

C<$new> is valid if it is both defined and not a reference type.

=item I<bool> or I<boolean>

C<$new> is valid if it is defined and is boolean (ie 0 or 1).

=item I<integer>

C<$new> is valid if it is a string consisting of one or more digits (i.e. a
non-negative integer).

=item I<number>

C<$new> is valid if it is a string of digits, optionally followed by a dot and
one or more digits (i.e. a non-negative decimal number).

=item I<nonempty>

C<$new> is valid if it is a non-empty string (and not a reference type).

=item I<ipaddr>

C<$new> is valid if it is a string conforming to IPv4 address syntax.

=back

=back

=cut

sub validate;

sub validate {

    if ( @_ and ref $_[0] and ref $_[0] eq __PACKAGE__ ) {
        shift;
    }

    my ( $schema, $new, $old, @keys ) = @_;

    local $" = '->';

    for ($schema) {
        defined
          or croak "Undefined value in schema\n";

        ref eq 'HASH' and do {
            ref $new eq 'HASH'
              or die "Bad @keys entry: $new (expecting a hashref)\n";

            $old ||= {};

            ref $old eq 'HASH'
              or die
"Unable to merge with old @keys entry: $old (expecting a hashref)\n";

            for my $key ( sort keys %$schema ) {
                next unless exists $new->{$key};
                my $value = $new->{$key};

                unless ( defined $value ) {
                    delete $old->{$key};
                    next;
                }

                $old->{$key} = validate $schema->{$key}, $value, $old->{$key},
                  @keys, $key;
            }

            return $old;
        };

        ref eq 'ARRAY' and do {
            ref $new eq 'ARRAY'
              or die "Bad @keys entry: $new (expecting an arrayref)\n";
            @$schema
              or croak "Schema contains empty arrayref";
            @$new % @$schema == 0
              or die "Bad @keys entry: contains ", scalar(@$new),
              ' elements (expecting a multiple of ', scalar(@$schema), ")\n";

            $old ||= [];

            ref $old eq 'ARRAY'
              or die
"Unable to merge with old @keys entry: $old (expecting an arrayref)\n";

            for ( my $key = 0 ; $key < @$new ; $key++ ) {
                my $entry;

                if ( defined( my $value = $new->[$key] ) ) {
                    $entry = validate $schema->[ $key % @$schema ], $value,
                      undef, @keys, $key;
                }

                push @$old, $entry;
            }

            return $old;
        };

        ref eq 'Regexp' and do {
            defined $new && $new =~ $schema
              or die "Bad @keys entry: $new (does not match $schema)\n";
            return $new;
        };

        ref eq 'CODE' and do {
            return $schema->( $new, $old, @keys );
        };

        /^any$/ and return $new;
        /^scalar$/ and do {
            defined $new && ref $new eq ''
              or die "Bad @keys entry: $new (expecting a scalar)\n";
            return $new;
        };
        /^(bool|boolean)$/ and do {
            defined $new && ref $new eq '' && $new =~ m/^[01]$/
              or die "Bad @keys entry: $new (expecting boolean)\n";
            return $new;
        };
        /^integer$/ and do {
            defined $new && ref $new eq '' && $new =~ m/^\d+$/
              or die "Bad @keys entry: $new (expecting a integer)\n";
            return $new;
        };
        /^number$/ and do {
            defined $new && ref $new eq '' && $new =~ m/^\d+(\.\d+)?$/
              or die "Bad @keys entry: $new (expecting a number)\n";
            return $new;
        };
        /^nonempty$/ and do {
            defined $new && ref $new eq '' && $new ne ''
              or die "Bad @keys entry: $new (expecting a non-empty string)\n";
            return $new;
        };
        /^ipaddr$/ and do {
            defined $new
              && ref $new eq ''
              && $new =~ m/^(\d+)\.(\d+).(\d+).(\d+)$/
              && 0 <= $1
              && $1 <= 255
              && 0 <= $2
              && $2 <= 255
              && 0 <= $3
              && $3 <= 255
              && 0 <= $4
              && $4 <= 255
              or die "Bad @keys entry: $new (expecting an IP address)\n";
            return $new;
        };

        croak "Weird schema terminal: $_";
    }
}

=item B<i_isa_class>

    $is_class = i_isa_class $thing;

Returns true if and only if C<$thing> is I<syntactically> a valid class name.

=cut

sub i_isa_class {

    if ( @_ and ref $_[0] and ref $_[0] eq __PACKAGE__ ) {
        shift;
    }

    return ( defined $_[0] and scalar $_[0] =~ m/^[A-Z]/ );
}

=item B<i_isa_host>

    $is_host = i_isa_host $thing;

Returns true if and only if C<$thing> is I<syntactically> a valid host name.

=cut

sub i_isa_host {

    if ( @_ and ref $_[0] and ref $_[0] eq __PACKAGE__ ) {
        shift;
    }

    return ( defined $_[0] and scalar $_[0] =~ m/^[a-z]/ );
}

=item B<type_list>

    @hosts = type_list \%m, @tags;

    @hosts = $obj->type_list(@tags);

Returns a list of hosts in C<\%m> that have a true value for all specified tags.

=cut

sub type_list {

    my (@args) = @_;

    my ( $m, @tags );

    if ( ref $args[0] and ref $args[0] eq __PACKAGE__ ) {
        my $self = shift @args;
        $m = $self->{m};            # $self
        @tags = grep { $_ } @args
          or croak "Usage: type_list(\@tags)";
    }
    else {
        $m = shift @args;
        $m and ref $m eq 'HASH' and ( @tags = grep { $_ } @args )
          or croak "Usage: Conform::Core::type_list(\\%m, \@tags)";
    }

    my @hosts;
    for my $host ( grep i_isa_host($_), sort keys %$m ) {
        push @hosts, $host unless grep !i_isa( $m, $host, $_ ), @tags;
    }
    @hosts;
}

=item B<i_isa>

    $value = i_isa \%m, $host, $tag;

    $value = $obj->i_isa($tag);

Conducts a pre-order traversal of the inheritance tree for C<$host>, and
returns the first value found for tag C<$tag>.

=cut

sub _i_isa;
sub _i_isa {
    my ( $m, $host, $tag, $seen ) = @_;

    not $seen->{$host}
      or return;
    exists $m->{$host}
      or return;

    my $d = $m->{$host}
      or return;
    ref $d eq 'HASH'
      or return;

    return $d->{$tag}
      if exists $d->{$tag};

    return $d->{ISA}->{$tag}
      if exists $d->{ISA}
          and ref $d->{ISA} eq 'HASH'
          and exists $d->{ISA}->{$tag};

    return 1
      if exists $d->{ISA}
          and ref $d->{ISA} eq 'ARRAY'
          and scalar grep { $_ eq $tag } @{ $d->{ISA} };

    $seen->{$host}++;

    my @keys;

    # do exists first so that $d->{ISA} isnt created, see sirz 55472
    if ( exists $d->{ISA} ) {
      if ( ref $d->{ISA} eq 'ARRAY' ) {
          push @keys, @{ $d->{ISA} }
      } else {
          push @keys, keys %{ $d->{ISA} }
      }
    }

    for my $k (sort @keys) {
        my $value = _i_isa($m, $k, $tag, $seen);
        return $value if $value;
    }


    return ();
}

sub i_isa {

    my (@args) = @_;

    my ( $m, $host, $tag );

    if ( ref $args[0] eq __PACKAGE__ ) {
        $m    = $args[0]->{m};
        $host = $args[0]->{host};
        $tag  = $args[1]
          or croak 'Usage: i_isa($tags)';
    }
    else {
        ( $m, $host, $tag ) = @args;
        $m and ref $m eq 'HASH' and $host and $tag
          or croak 'Usage: Conform::Core::i_isa(\%m, $host, $tag)';
    }

    return _i_isa( $m, $host, $tag, {} );
}

=item B<i_isa_fetchall>

    $values = i_isa_fetchall \%m, $host, $tag;
    @values = i_isa_fetchall \%m, $host, $tag;

    $values = $obj->i_isa_fetchall($tag);
    @values = $obj->i_isa_fetchall($tag);

Conducts a I<pre>-order traversal of the inheritance tree for C<$host>, and
returns a list or array reference of I<all> values found for tag C<$tag>.

=cut

sub _i_isa_fetchall;

sub _i_isa_fetchall {
    my ( $m, $host, $tag, $seen ) = @_;

    not $seen->{$host}
      or return;
    exists $m->{$host}
      or return;

    my $d = $m->{$host}
      or return;
    ref $d eq 'HASH'
      or return;

    my @ret;

    push @ret, $d->{$tag}
      if exists $d->{$tag};

    push @ret, $d->{ISA}->{$tag}
      if exists $d->{ISA}
          and ref $d->{ISA} eq 'HASH'
          and exists $d->{ISA}->{$tag};

    push @ret, 1
      if exists $d->{ISA}
          and ref $d->{ISA} eq 'ARRAY'
          and scalar grep { $_ eq $tag } @{ $d->{ISA} };

    $seen->{$host}++;

    if ( exists $d->{ISA} ) {

        push @ret,
          map { _i_isa_fetchall $m, $_, $tag, $seen }
          ref $d->{ISA} eq 'ARRAY'
          ? @{ $d->{ISA} }
          : sort keys %{ $d->{ISA} };
    }

    return @ret;
}

sub i_isa_fetchall {

    my (@args) = @_;

    my ( $m, $host, $tag );

    if ( ref $args[0] and ref $args[0] eq __PACKAGE__ ) {
        $m    = $args[0]->{m};      # $self
        $host = $args[0]->{host};
        $tag  = $args[1]
          or croak "Usage: i_isa_fetchall(\$tag)";
    }
    else {
        ( $m, $host, $tag ) = @args;
        $m and ref $m eq 'HASH' and $host and $tag
          or croak "Usage: Conform::Core::i_isa_fetchall(\\%m, \$host, \$tag)";
    }

    my @values = _i_isa_fetchall( $m, $host, $tag, {} );
    return wantarray ? @values : \@values;
}

=item B<i_isa_mergeall>

	$value = i_isa_mergeall \%m, $host, $tag, $behaviour;

	$value = $obj->i_isa_mergeall($tag, $behaviour);

Conducts a I<pre>-order traversal of the inheritance tree for C<$host>, finds
I<all> values for tag C<$tag>, then merges all values.  It uses Hash::Merge
for merging. The default behaviour (LEFT_PRECEDENT) of Hash::Merge applies
unless you specify RIGHT_PRECEDENT in I<$behaviour>.

A brief summary of the behaviour (gleaned from Hash::Merge Pod)

		LEFT TYPE   RIGHT TYPE      LEFT_PRECEDENT       RIGHT_PRECEDENT
		SCALAR      SCALAR            $a                   $b
		SCALAR      ARRAY             $a                   ( $a, @$b )
		SCALAR      HASH              $a                   %$b
		ARRAY       SCALAR            ( @$a, $b )          $b
		ARRAY       ARRAY             ( @$a, @$b )         ( @$a, @$b )
		ARRAY       HASH              ( @$a, values %$b )  %$b
		HASH        SCALAR            %$a                  $b
		HASH        ARRAY             %$a                  ( values %$a, @$b )
		HASH        HASH              merge( %$a, %$b )    merge( %$a, %$b )

=over

=item *

I<$behaviour> can either be 'LEFT_PRECEDENT' or 'RIGHT_PRECEDENT'.  Defaults to 'LEFT_PRECEDENT'

=back

=cut

sub i_isa_mergeall {

    my (@args) = @_;

    my ( $m, $host, $tag, $behaviour );

    if ( ref $args[0] and ref $args[0] eq __PACKAGE__ ) {
        $m    = $args[0]->{m};      # $self
        $host = $args[0]->{host};
        $tag  = $args[1]
          or croak "Usage: i_isa_mergeall(\$tag, [\$behaviour])";
        $behaviour = $args[2];
    }
    else {
        ( $m, $host, $tag, $behaviour ) = @_;
        $m and ref $m eq 'HASH' and $host and $tag
          or croak
"Usage: Conform::Core::i_isa_mergeall(\\%m, \$host, \$tag, [\$behaviour])";
    }

    my $reset_behaviour = Hash::Merge::get_behavior();
    $behaviour ||= 'LEFT_PRECEDENT';

    my $merged = eval {

        croak
"Invalid merge behaviour ($behaviour). Must be either 'LEFT_PRECEDENT' or 'RIGHT_PRECEDENT'"
          unless $behaviour =~ m/^(LEFT|RIGHT)_PRECEDENT/;

        Hash::Merge::set_behavior($behaviour);

        my $merge;

        for ( i_isa_fetchall $m, $host, $tag ) {
            unless ( defined $merge ) {
                $merge = $_;
            }
            else {
                $merge = Hash::Merge::merge( $merge, $_ );
            }
        }

        return $merge;
    };
    if ( my $err = $@ ) {
        Hash::Merge::set_behavior($reset_behaviour);
        die $err;
    }

    return $merged;
}

=item B<i_isa_merge>

    $value = i_isa_merge \%m, $host, $tag, $schema, $default;

    $value = $obj->i_isa_merge($tag, $schema, $default);

Conducts a I<post>-order traversal of the inheritance tree for C<$host>, finds
I<all> values for tag C<$tag>, then merges them with B<validate> according to
C<$schema>.

C<$default> may be provided to specify the default value to which the tag
entries are merged.

=cut

sub i_isa_merge {

    my (@args) = @_;

    my ( $m, $host, $tag, $schema, $default );

    if ( ref $args[0] and ref $args[0] eq __PACKAGE__ ) {
        $m    = $args[0]->{m};      # $self
        $host = $args[0]->{host};
        $tag  = $args[1]
          or croak "Usage: i_isa_merge(\\%m, \$host, \$tag)";
        $schema  = $args[2];
        $default = $args[3];
    }
    else {
        ( $m, $host, $tag, $schema, $default ) = @_;
        $m and ref $m eq 'HASH' and $host and $tag
          or croak "Usage: Conform::Core::i_isa_merge(\\%m, \$host, \$tag)";
    }

    my @entries = reverse i_isa_fetchall $m, $host, $tag;

    my $config;
    $config = validate $schema, $default, $config, '<default>'
      if defined $default;
    $config = validate $schema, $_, $config, $tag for @entries;
    $config;
}

=item B<ints_on_host>

    @ints = ints_on_host \%m, $host;

    @ints = $obj->ints_on_host($host);
    @ints = $obj->ints_on_host(); # defaults to the host defined at creation

Returns an array reference or list of interfaces on the specified host. Loopback
and tunnel interfaces are filtered out. Interfaces I<retain> their C<int_>
prefix.

=cut

sub ints_on_host {

    my (@args) = @_;

    my ( $m, $host );

    if ( ref $args[0] and ref $args[0] eq __PACKAGE__ ) {
        $m = $args[0]->{m};
        $host = $args[1] || $args[0]->{host};
    }
    else {
        ( $m, $host ) = @args;
        $m and ref $m eq 'HASH' and $host
          or croak "Usage: Conform::Core::ints_on_host(\\%m, \$host)";
    }

    my $h = $m->{$host}
      or return;
    ref $h eq 'HASH'
      or return;

    return sort grep /^int_(?!lo|tunl)/, keys %$h

}

=item B<ips_on_host>

    $ip  = ips_on_host \%m, $host;
    @ips = ips_on_host \%m, $host;

    $ip  = $obj->ips_on_host($host);
    @ips = $obj->ips_on_host($host);
    $ip  = $obj->ips_on_host(); # defaults to the host defined at creation
    @ips = $obj->ips_on_host();

In scalar context returns the "primary" IP of this host. In list context,
returns all IPs for this host, with the "primary" IP first.

IPs on loopback and tunnel interfaces are ignored.

=cut

sub ips_on_host {

    my (@args) = @_;

    my ( $m, $host );

    if ( ref $args[0] and ref $args[0] eq __PACKAGE__ ) {
        $m = $args[0]->{m};                     # $self
        $host = $args[1] || $args[0]->{host};
    }
    else {
        ( $m, $host ) = @args;
        $m and ref $m eq 'HASH' and $host
          or croak "Usage: Conform::Core::ips_on_host(%m, \$host)";
    }

    my $h = $m->{$host}
      or return;
    ref $h eq 'HASH'
      or return;

    my @ips;
    for ( ints_on_host $m, $host ) {
        my $int = $h->{$_}
          or next;
        ref $int eq 'HASH'
          or next;
        my $ip = $int->{ip}
          or next;

        if ( $int->{primary} ) {
            unshift @ips, $ip;
        }
        else {
            push @ips, $ip;
        }
    }

    return wantarray ? @ips : $ips[0];
}

=back

=head1 DEPRECATED FUNCTIONS

=over

=item B<build_netgroups>

    $groups = build_netgroups;

Equivalent to:

    use Conform::Core::Netgroups;
    $groups = Conform::Core::Netgroups::all;

=cut

sub build_netgroups {
    _deprecated
      build_netgroups => "Conform::Core::build_netgroups is deprecated;\n",
      "use Conform::Core::Netgroups::all instead\n";
    Conform::Core::Netgroups::all();
}

=item B<expand_netgroup>

    @ips = expand_netgroup \%groups, $group;

Equivalent to:

    use Conform::Core::Netgroups;
    @ips = Conform::Core::Netgroups::expand($group);

Note that the initial C<\%groups> parameter is no longer necessary.

=cut

sub expand_netgroup {
    _deprecated
      expand_netgroup =>
      "Conform::Core::expand_netgroup(\\%groups, \$group) is deprecated;\n",
      "use Conform::Core::Netgroups::expand(\$group) instead\n",
      "(note that \\%groups is not needed)\n";

    my ( $groups, $group ) = @_;
    $groups and ref $groups eq 'HASH' and $group
      or croak "Usage: Conform::Core::expand_netgroup(\\%groups, \$group)";
    $groups == Conform::Core::Netgroups::all()
      or croak
      "\\%groups parameter passed to Conform::Core::expand_netgroup must\n",
      "have been generated by Conform::Core::build_netgroups (deprecated)\n",
      "or Conform::Core::Netgroups::all\n";

    Conform::Core::Netgroups::expand($group);
}

=back

=cut

1;

=head1 SEE ALSO

L<conform>

=cut
