#!/bin/false
=encoding utf8

=head1 NAME

Conform::Core::Netgroups - Conform netgroup functions

=head1 SYNOPSIS

    use Conform::Core::Netgroups qw(:all :deprecated);

    $groups  = Conform::Core::Netgroups::all;
    @entries = Conform::Core::Netgroups::get($group);
    @ips     = Conform::Core::Netgroups::expand($group);

    $groups  = Conform::Core::Netgroups::getfromip($ip);
    %groups  = Conform::Core::Netgroups::getfromip($ip);
    @groups  = Conform::Core::Netgroups::expandfromip($ip);

=head1 DESCRIPTION

The Conform::Core::Netgroups module contains functions for retrieving netgroup
information.

=cut

package Conform::Core::Netgroups;

use strict;

use Conform::Core;

use vars qw($VERSION);
$VERSION = (qw$Revision: 1.21 $)[1];

# this is stolen from http://cpansearch.perl.org/src/NEELY/Data-Validate-IP-0.11/lib/Data/Validate/IP.pm
# it should be factored out in to an Conform::Core module of its own

## This next three functions should be refactored into another module.
## Note to self. Do that :)

sub _valid_ip {
    my $value = shift;

    return unless defined($value);
    my (@octets) = $value =~ m/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/;
    return unless ( @octets == 4 );

    foreach (@octets) {

        #return unless ($_ >= 0 && $_ <= 255);
        return unless ( $_ >= 0 && $_ <= 255 && $_ !~ m/^0\d{1,2}$/ );
    }

    return join( q{.}, @octets );
}

# stolen from http://cpansearch.perl.org/src/SARENNER/Net-IPAddress-1.10/IPAddress.pm

sub _ip2num {
    return ( unpack( 'N', pack( 'C4', split( m{\.}, $_[0] ) ) ) );
}

sub _num2ip {
    return ( join( q{.}, unpack( 'C4', pack( 'N', $_[0] ) ) ) );
}

sub _mask_ip {
    my ( $ipaddr, $mask ) = @_;
    my $addr = _valid_ip($ipaddr) ? _ip2num($ipaddr) : $ipaddr;

    if ( _valid_ip($mask) ) { # Mask can be sent as either "255.255.0.0" or "16"
        $mask = _ip2num($mask);
    }
    else {

        #$mask = ( ( ( 1 << $mask ) - 1 ) << ( 32 - $mask ) );
        #$mask = 2**32 - 2**(32-$mask);
        $mask = 4294967296 - 2**( 32 - $mask );
    }
    return $addr & $mask;
}

my $groups;

sub _load_groups {
    $groups = {};

    # TODO
}

=head1 FUNCTIONS

=over

=item B<init>

    Conform::Core::Netgroups::init (groups => \%groups);

Initialise Conform::Core::Netgroups with a 'groups' HASH

=over

=item I<groups>

A complete HASHref of 'netgroups'.

These are of the format:

	'name' => [
		desc => ' ',
		addr => ' ',
	],

=back

=cut

sub init {
    my %args = @_;

    $args{groups} and ref $args{groups} eq 'HASH'
      or die "Usage: @{[__PACKAGE__]}::init(groups => \%groups)";

    $groups = $args{groups};
}

=item B<all>

    $groups = Conform::Core::Netgroups::all;

Returns a hash reference describing all known netgroups.

The returned hash reference maps netgroup names to an array of netgroup
entries. Each netgroup entry is a hash reference containing:

=over

=item I<addr>

An IP address or IP range.

=item I<desc>

A description for the netgroup entry.

=back

Additionally, netgroup entries derived from Netgroup tags from the machines
file also contain a I<host> value.

=cut

sub all {
    _load_groups unless $groups;
    $groups;
}

=item B<get>

    @entries = Conform::Core::Netgroups::get($group);

Returns a list of hash references describing the IPs and IP ranges allocated to
the specified netgroup. Equivalent to:

    @entries = @{Conform::Core::Netgroups::all->{$group} || []};

=cut

sub get {
    my $group = shift
      or die "Usage: Conform::Core::Netgroups::get(\$group)\n";

    _load_groups unless $groups;
    @{ $groups->{$group} || [] };
}

=item B<expand>

    @ips = Conform::Core::Netgroups::expand($group);

Returns a list of IPs and IP ranges for the specified netgroup.

=cut

sub expand {
    my $group = shift
      or die "Usage: Conform::Core::Netgroups::expand(\$group)\n";
    map $_->{addr}, get $group;
}

=item B<getfromip>

    %groups = Conform::Core::Netgroups::getfromip($ip);
    $groups = Conform::Core::Netgroups::getfromip($ip);

Returns a list of keys and hash references describing the IPs and IP ranges in the netgroups 
for which the specified ip address is a member.

In scalar context returns a hashref, in list returns the hash.

=cut

sub getfromip {

    my $ip = shift
      or die "Usage: Conform::Core::Netgroups::getfromip(\$ip)\n";

    die "Conform::Core::Netgroups::getfromip(\$ip) \$ip needs to be a valid ip address\n"
      unless _valid_ip($ip);

    _load_groups unless $groups;

    $ip = _ip2num($ip);

    my %return;

  WHILELOOP:
    while ( my ( $key, $val ) = each %{$groups} ) {

      FORLOOP:
        for my $net ( @{$val} ) {

            $net->{addr} =~ s{/32$}{};    # crude but oh well

            if ( my ( $n, $m ) = $net->{addr} =~ m{([\d\.]+)/(\d{1,2})} )
            {                             # look for a subnet
                if ( _mask_ip( $n, $m ) == _mask_ip( $ip, $m ) )
                {    # ip in subnet and jump to the next group
                    $return{$key} = $val;
                    next WHILELOOP;
                }
                next FORLOOP;
            }

            # ips are equal
            if ( $ip == _ip2num( $net->{addr} ) ) {
                $return{$key} = $val;
                next WHILELOOP;
            }

        }
    }

    if (%return) {
        return wantarray ? %return : \%return;
    }

    return;

}

=item B<expandfromip>

    @groups = Conform::Core::Netgroups::expandfromip($ip);

Returns a list netgroup names for which the specified ip address is a member.

=cut

sub expandfromip {

    # just make the other function do all the work :)
    return sort keys %{ getfromip(@_) || {} };

}

=back

=cut

1;
