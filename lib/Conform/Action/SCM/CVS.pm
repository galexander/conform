package Conform::Action::SCM::CVS;
use warnings;
use strict;

use Moose;
use Conform::Logger qw($log trace note debug notice warn fatal);
use Conform::ExecutionContext;
use Data::Dump qw(dump);
use IPC::Open3 qw(open3);
use IO::Handle ();
use Carp;
use POSIX qw(strftime);
use IO::Select;
use Errno qw(EINTR EAGAIN);
use Getopt::Long;
use File::Path qw(mkpath);


use Conform::Action::Plugin;

use Conform::Core::IO qw(:all);
use Carp qw(croak);

our $VERSION = $Conform::VERSION;
my $order = 0;

use vars qw/%m $iam $hostname $domain/;
use vars qw/$_path $_module $_class/;
use subs qw/i_isa i_isa_fetchall debug command package_check type_list note/;


my @servers = qw(cvs); #CP: 17/4/13: This appears to just blat whatever we got from typelist

sub _process_cvs_output {
    my $output = shift;

    return 1 unless $output; # return if there is no output

    my $clash = "CVS Update/Checkout conflict - resolve before continuing\n";

    my @checks = (
        { qr/s*C\s+/ => {
            msg    => $clash,
            action => sub { die(@_) }
            },
        },
        { qr/\s*conflicts\s+found\s+in/ => {
            msg    => $clash,
            action => sub { die(@_) }
            },
        },
        { qr/^M\s/ => {
            msg => "Local copy has uncontrolled changes (M)\n",
            action => sub { warn(@_) }
            },
        },
        { qr/^\?\s/ => {
            msg => "Uncontrolled file in checkout location (?)\n",
            action => sub { warn(@_) }
            },
        },
    );

    my $line = '-' x 40;
    my $flag;

    for my $chk (@checks) {
        while ( my ( $regex, $options ) = each %$chk ) {
            if ( $output =~ m/$regex/m ) {
                my $action = $options->{'action'} || \&die;

                warn $line, "\nCVS output:\n", $output, $line, "\n"
                    unless $flag++; # only do this once

                my $msg = $options->{'msg'} || "CVS output matched regex: $regex";
                $action->($msg);
            }
        }
    }

    note "CVS output:\n$output\n"
        unless $flag;

    return 1

}

sub _path_to_base {

    my $path = shift or return;

    # remove duplicate slashes
    $path =~ s,//+,/,g;
    $path =~ s,/+$,,g;

    my @path = split /\//, $path;
    my $dir = pop @path;

    die "Bad path in cvs module\n"
      unless ($dir);

    warn
"Placing CVS modules in /home is deprecated in rhel6, please put them in /opt\n"
      if ( $path[1] eq 'home' and $dir !~ m/^snmp/i )
      ;    # XXX snmp is a work around for now. remove it please

    return ( join( '/', @path ), $dir )

}

sub _get_cvs_versions {
    my ( $dir, $list ) = @_;

    return unless -d $dir;
    die '_get_cvs_versions wasnt passed a hash ref'
      unless ( $list && ref $list eq 'HASH' );

    my $file = slurp_file("$dir/CVS/Entries");
    for my $line ( split( /\n/, $file ) ) {
        # handle subdirs
        if (my ($newdir) = $line =~ m/^D\/([^\/]+)/) {
            _get_cvs_versions( "$dir/$newdir", $list );
            next;
        }

        my ( undef, $filename, $version, $date, undef, $tag ) = split(/\//,$line);
        next unless $filename;
        $list->{"$dir/$filename"} = $version;
    }

    return;
}

my %cvs_seen;
my %path_used;
my %conform_cfg;

my $cvs_checkout_path = "/opt";

sub CVS
    : Action
    : Args()
    : Desc(Checkout CVS modules) {

    debug "CVS (%s)", dump($_[0]);
    
    local @ARGV = @ARGV;
    my $args = shift;
    my ($path, $to_checkout) = %$args;
    my $agent = pop;

    $path = $path =~ m{^/} ? $path : "$cvs_checkout_path/$path";

    no strict 'refs';
    our (%m, $iam, $_path, $_class, $_repository);
    *m = $agent->nodes;
    $iam = $agent->iam;


    debug "Looking at CVS path '$path'";

    unless ( ref $to_checkout and ref $to_checkout eq 'HASH' )
    {
        warn "CVS. Not a hashref for path '$path'. skipping!\n";
        return;
    }

    my ( $repos, $module, $rev, $prune, $prio ) =
      @{ $to_checkout }{ 'repository', 'module', 'rev', 'prune',
        'prio' };

    if ($cvs_seen{"$to_checkout"}++) { # i want the hashref text of "HASH(0xF00BAA)"

        debug " module '$module' with path '$path' already processed, skipping\n";
        return;
    }

    unless ($module) {
        warn "No CVS 'module' defined for path $path! skipping!\n";
        return;
    }

    unless ($rev) {
        $rev = 'HEAD';
        debug " module '$module' defaulting to HEAD\n"
    }

    die
"CVS revision cant be a number. Found revision '$rev' for module '$module'"
      if $rev =~ m/^[\d\.]+$/;    # ie its all numbers and dots

    if ( $path_used{$path}++ ) {
        warn
"CVS path '$path' already used for check out, skipping module '$module' with rev '$rev'\n";
        return;
    }

    if ( i_isa("Disable_cvs_$module") ) {
        warn
          "CVS module '$module' with rev '$rev' disabled, skipping\n";
        return;
    }
    my ( $base, $dir ) = _path_to_base($path);

    note "Processing CVS module '$module:$rev' in '$path'";

    my $r = $repos ||= 'repos';
    $repos = ":pserver:conform\@cvs.optusnet.com.au:/home/cvs/$repos"
      unless $repos =~ m/:pserver:/;

    # make a couple of local variables to be used by conform.cfg
    local ( $_path, $_module, $_class ) =
      ( $path, $module, "CVS_${r}_$module" );

    # make sure _class is unique
    if ( $m{$iam}{ISA}{$_class} ) {
        my $bump = 1;
        $bump++ while ( $m{$iam}{ISA}{ $_class . "_$bump" } );
        $_class .= "_$bump";
    }

    if ($base) {
        mkpath( $base, 0, 0755 );
        chdir($base) or die "Couldn't create directory $base\n";
    }

    my @cvs_args = $rev eq 'HEAD' ? ('-A') : ( '-r', $rev );
    push( @cvs_args, '-P' )
      if $prune;

    my ($abbrev_repos) = $repos =~ m{^.*?([^/]*)$};
    debug(" Going to check out $abbrev_repos:$module:$rev to $path\n");
    if ( chdir $path ) {
        debug "  Chdir to $path success.";
        my %oldversions;
        _get_cvs_versions( '.', \%oldversions );
        if ( -d 'CVS' ) {
            debug "  $path/CVS exists, checking the contents";
            open my $REP, '<', 'CVS/Repository'
              or die "no 'Repository' file in CVS dir: $!";
            chomp( my $check_module = <$REP> );
            close $REP;

            unless ( $check_module eq $module
                or $check_module eq 'CVSROOT/Emptydir' )
            {
                die
"A different CVS module has already been checked out into $path";
            }

            open my $ROOT, '<', 'CVS/Root'
              or die "no Root file in CVS dir in '$path': $!";
            chomp( my $check_repos = <$ROOT> );
            close $ROOT;

            unless ( $check_repos eq $repos ) {
                note "  Re-writing CVS/Root in $path";

                my @search = ($path);
                my @found;

                while ( my $foo = shift(@search) ) {
                    opendir( my $DIR, $foo ) or next;

                    while ( my $ent = readdir($DIR) ) {
                        next if $ent =~ m/^\.\.?$/;
                        next if -l "$foo/$ent";
                        next unless -d "$foo/$ent";

                        if ( $ent eq 'CVS' ) {
                            push @found, "$foo/$ent/Root";
                        }
                        else {
                            push @search, "$foo/$ent";
                        }
                    }

                    closedir($DIR);
                }

                for (@found) {
                    open( my $ROOT, '>', $_ )
                        or die "Couldn't open $_: $!";
                    print $ROOT "$repos\n";
                    close($ROOT);
                }

            }
            else {
                debug "   CVS/Root looks good";
            }

        }
        else {
            die "Not a CVS checkout in $path\n";
        }

        debug "  Now running a cvs update in $path";
        unshift @cvs_args,
          ( 'cvs', '-q', 'update', '-d' );    # on the front
        debug '   CVS command will be: ' . join( ' ', @cvs_args );

        my $up_output;
        command(
            @cvs_args,
            {
                success => "  Updated '$module:$rev' in $path",
                failure => "CVS update to '$path' failed.",
                capture => \$up_output,
            }
        ) and die "Couldn't update: $!";
        _process_cvs_output($up_output);

        # Get new checked out file versions
        my %newversions;
        _get_cvs_versions( q|.|, \%newversions );

        # Show which files changed
        for my $file ( keys %newversions ) {
            my $fn = $file;
            $fn =~ s/^\.\///;
            $oldversions{$file} ||= q();
            next if ( $newversions{$file} eq $oldversions{$file} );
            debug(
"  UPDATE $module|$fn|$oldversions{$file}|$newversions{$file}|$repos"
            );
        }

        for my $file ( keys %oldversions ) {
            my $fn = $file;
            $fn =~ s{^\./}{};
            debug("  UPDATE $module|$fn|$oldversions{$file}||$repos")
              if ( !$newversions{$file} );
        }

    }
    else {
        debug "  Couldnt chdir to $path, so going with a cvs checkout";
        unshift @cvs_args,
          ( 'cvs', '-q', '-d', $repos, 'checkout', '-d', $dir )
          ;    # on the front
        push @cvs_args, $module;    # on the end
        debug '   CVS command will be: ' . join( ' ', @cvs_args );

        my $co_output;
        command(
            @cvs_args,
            {
                success => "  Checked out '$module:$rev' to $path",
                failure => "CVS checkout to '$path' failed.",
                capture => \$co_output,
            }
        ) and die "Couldn't CVS checkout: $!";
        _process_cvs_output($co_output);

        chdir $path;

        debug "  Now running a cvs update in $path to fix up CVS/Entries (see sirz 53156)";
        @cvs_args = ( 'cvs', '-q', 'update', '-d' );
        debug '   CVS command will be: ' . join( ' ', @cvs_args );

        my $up_output;
        command(
            @cvs_args,
            {
                success => "  Updated '$module:$rev' in $path",
                failure => "CVS update to '$path' failed.",
                capture => \$up_output,
            }
        ) and die "Couldn't update: $!";
        _process_cvs_output($up_output);

        # Get new checked out file versions
        my %newversions;
        _get_cvs_versions( q|.|, \%newversions );

        for my $file ( keys %newversions ) {
            my $fn = $file;
            $fn =~ s{^\./}{};
            debug("  UPDATE $module|$fn||$newversions{$file}|$repos")
        }

    }

    # machines.cfg should not do anything other than modify the "machines" %m hash.
    # this is mostly here to maintain functionality, one CVS module can require another.
    #
    for my $config ("$path/machines.cfg") {
        if ( -f $config ) {
            $m{$iam}{ISA}{$_class} = 1;

            debug("  Executing $path/machines.cfg\n");
            do $config;
            die "$config: $@" if $@;
            $m{$_class}||={};
        }
        else {
            debug("  No $path/machines.cfg. Continuing\n");
        }
    }

    # conform.cfg files are executed after all CVS modules have been checked out,
    # so we can do priority based execution.
    #
    for my $config ("$path/conform.cfg") {
        if ( -f $config ) {

            $prio = defined $prio
                    ? $prio + 125
                    : 125;

            # stash details away for later
            #
            $conform_cfg{$config} = {
                cfg    => $config,
                prio   => $prio,
                order  => $order++,
                path   => $_path,
                module => $_module,
                repository => $_module,
                class  => $_class . "_conformcfg",
            };

            Action 'Conform_module', $conform_cfg{$config};
        }
        else {
            debug("  No $path/conform.cfg. Continuing...\n");
        }
    }

}



1;
