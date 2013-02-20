package Conform::Plugin;

=head1  NAME

    Conform::Plugin

=cut

=head1  SYNOPSIS

    use Conform::Plugin;

    Id      ("My::Plugin::ID");
    Name    ("My::Plugin");
    Version ("1.2");

    sub plugin_method
        Attribute: {
    }

=cut


use Mouse;
use Scalar::Util qw(refaddr);

my %Id;
my %Name;
my %Version;

sub import {
    my $caller = caller;
    my @args = splice(@_, 1, $#_);
    if (@args && @args %2 == 0) {
        my %args = @args;
        $caller = delete $args{package}
                    if exists $args{package};
    }
    no strict 'refs';
    no warnings 'redefine';
    *{"${caller}\::MODIFY_CODE_ATTRIBUTES"}
            = \&MODIFY_CODE_ATTRIBUTES;
    *{"${caller}\::FETCH_CODE_ATTRIBUTES"}
            = \&FETCH_CODE_ATTRIBUTES;

    *{"${caller}\::Id"}         = \&Id;
    *{"${caller}\::Name"}       = \&Name;
    *{"${caller}\::Version"}    = \&Version;

    my $identifier = $caller;
    
    # TODO make this work - setId, setName, setVersion on objects that this plugin spits out

    *{"${caller}\::getId"}      = sub { _getId      ($identifier) };
    *{"${caller}\::getName"}    = sub { _getName    ($identifier) };
    *{"${caller}\::getVersion"} = sub { _getVersion ($identifier) };

    $_[0]->SUPER::import(@_);
}


has 'attr' => ( is => 'rw', isa => 'ArrayRef', default => sub { [] }  );

sub get_attr {
    my $self = shift;
    my $attr = shift;
    for (@{$self->attr}) {
        my ($name, $value) = (ref $_ eq 'HASH'
                                ? each %$_
                                : (ref $_ eq 'ARRAY'
                                     ? ($_->[0], $_->[1])
                                     : (!ref $_
                                            ? ($_ => 1)
                                            : ())));
                                
        if ($name eq $attr) {
            return $value;
        }
    }
}

sub get_attrs {
    my $self = shift;
    my $attr = shift;
    my @attr = ();
    for (@{$self->attr}) {
        my ($name, $value) = (ref $_ eq 'HASH'
                                ? each %$_
                                : (ref $_ eq 'ARRAY'
                                     ? ($_->[0], $_->[1])
                                     : (!ref $_
                                            ? ($_ => 1)
                                            : ())));

        if ($name eq $attr) {
            push @attr, $attr;
        }
    }
    return wantarray
            ? @attr
            :\@attr;
}


sub Id {
    my $caller = caller;
    $Id{$caller} = shift;
}

sub _getId {
    my $caller = shift;
    return $Id{$caller} if defined $Id{$caller};
    $caller;
}

sub Name {
    my $caller = caller;
    $Name{$caller} = shift;
}

sub _getName {
    my $caller = shift;
    return $Name{$caller} if defined $Name{$caller};
    $caller =~ s/^Conform:://;
    $caller;
}

sub Version {
    my $caller = caller;
    $Version{$caller} = shift;
}

sub _getVersion {
    my $caller = shift;
    return $Version{$caller} if defined $Version{$caller};

    no strict 'refs';
    if (defined ${"${caller}\::VERSION"}) {
        return  ${"${caller}\::VERSION"};
    }
    return undef;
}


my %attrs = ();

sub MODIFY_CODE_ATTRIBUTES {
    my ($package, $subref, @attrs) = @_;
    $attrs{ $package } { refaddr $subref } = \@attrs;
    ();
}

sub FETCH_CODE_ATTRIBUTES {
    my ($package, $subref) = @_;
    my $attrs = $attrs{ $package } { refaddr $subref };
    return @{$attrs || [] };
}

1;
