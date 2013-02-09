package Conform::Plugin;
use strict;
use Scalar::Util qw(refaddr);

my %Id;
my %Name;
my %Version;

use Mouse;

has 'attr' => ( is => 'rw', isa => 'ArrayRef' );


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

    *{"${caller}\::getId"}      = sub { getId      ($caller) };
    *{"${caller}\::getName"}    = sub { getName    ($caller) };
    *{"${caller}\::getVersion"} = sub { getVersion ($caller) };
}

sub Id {
    my $caller = caller;
    $Id{$caller} = shift;
}

sub getId {
    my $caller = shift;
    return $Id{$caller} if defined $Id{$caller};
    $caller;
}

sub Name {
    my $caller = caller;
    $Name{$caller} = shift;
}

sub getName {
    my $caller = shift;
    return $Name{$caller} if defined $Name{$caller};
    $caller =~ s/^Conform:://;
    $caller;
}

sub Version {
    my $caller = caller;
    $Version{$caller} = shift;
}

sub getVersion {
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
