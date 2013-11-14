package Conform::Action::SCM::GIT;
use Moose;
use Conform::Logger qw($log notice fatal note debug warn trace);
use Data::Dump qw(dump);
use IPC::Open3 qw(open3);
use IO::Handle ();
use Carp;
use POSIX qw(strftime);
use IO::Select;
use Errno qw(EINTR EAGAIN);
use Getopt::Long;
use File::Path qw(mkpath);

use constant GIT_NO_CHANGES  => 1;
use constant GIT_CHECKED_OUT => 2;
use constant GIT_UPDATED     => 4;
use constant GIT_CMD_READ_TIMEOUT => 180;

use constant GIT_MAX_UNTRACKED_FILES => 10;
use constant GIT_MAX_TRACKED_LOCAL_CHANGES => 5;
use constant GIT_DEFAULT_CHECKOUT_PATH => '/opt';

use Conform::Action::Plugin;

use Conform::Core::IO qw(:all);
use Carp qw(croak);

our $VERSION = $Conform::VERSION;
my $order = 0;

sub _cmd3 {
    my $cmd = shift;
    my %args = @_;

    $args{timeout} ||= GIT_CMD_READ_TIMEOUT;
    $args{read_timeout} ||= $args{timeout};
    $args{wait_timeout} ||= $args{timeout};
    $args{kill_timeout} = 10 unless exists $args{kill_timeout};


    my ($out, $err) = map new IO::Handle(), (0..1);
    my $stdout;
    my $stderr;

    my $pid = open3(undef, $out, $err, $cmd);

    $out->autoflush;
    $err->autoflush;

    my $select = IO::Select->new();

    $select->add($_) for ($out, $err); 

    my %handles = (
            fileno($err) => \$stderr,
            fileno($out) => \$stdout,
    );

    while (my @r = $select->can_read($args{read_timeout})) {

            for my $handle (@r) {

                    my $data;
                    my $eof;

                    if (my $output = $handles{fileno($handle)}) {
                            my $err_cnt = 0;
                            my $byte_cnt = 0;

                            READ: {
                                    $byte_cnt = sysread($handle, $data, 1024);
                                    redo READ if ((!defined $byte_cnt) && $! == EAGAIN || $! == EINTR)
                                                    && $err_cnt++ < 5;

                            }
                            die "$!" unless defined $byte_cnt;
                            $eof++ if $byte_cnt == 0;
                            $$output .= $data unless $eof;

                    }

                    $select->remove($handle) or $handle->close if $eof;
            }
    }

    my $status;

    if ($select->handles) { # timeout
        local $SIG{ALRM} = sub { die "alarm" };
        kill TERM => $pid;
        eval {
            alarm $args{wait_timeout};
            waitpid $pid, 0;
            alarm  0;
            $status = $?
        };
        if (my $term = $@) {
            die $term unless $term eq 'alarm';
            note "timeout sending SIGTERM to kill $cmd";
            kill KILL => $pid;
            eval {
                alarm $args{kill_timeout};
                waitpid $pid, 0;
                alarm 0;
                $status = $?
            };
            if (my $kill = $@) {
                die $kill unless $kill eq 'alarm';
                die "[timeout sending SIGKILL to kill $cmd";
            }
        }
    } else {
        waitpid $pid, 0;
        $status = $?;
    }

    die "error getting status for $cmd (probably due to timeout)"
        unless defined $status;
    
    if ($status >> 8) {
        $stderr .= sprintf "%s exited with %d", $cmd, ($status >> 8);
    } elsif ($status) {
        $stderr .= sprintf "%s exited with signal (%d)", $cmd, ($status & 0x7f);
    } 

    return ($status, $stdout, $stderr);
}

sub _git {
    my $cmd = shift;

    $cmd = "git $cmd" unless $cmd =~ /^git/;

    trace "running $cmd";
    my ($status, $out, $err) = _cmd3 ($cmd, @_);

    if ($status != 0) {
        die "error running $cmd: $err";
    }

    trace "CMD: $out" if $out;
    trace "ERR: $err" if $err;

    return ($out,$err);
}



sub _git_local_branches {
    my ($out, $err) = _git "branch -l";

    my %b = ();

    for (split /\n/, $out) {
        if (/^(\*)?\s+(\S+)$/) {
            my ($current, $name) = ($1, $2);
            $b{$name} = defined $current ? 1 : 0;
        }
    }
    return %b;
}

sub _git_remote_branches {
    my ($out, $err) = _git "branch -r";

    my %b = ();

    for(split /\n/, $out) {
        s/^\s+//;
        s/\s+$//;
        s/^origin\///;
        $b{$_} = 0;
    }

    return %b;
}

sub _git_ls_remote {
    my $origin = shift;
    my %refs = ();
    my ($out, $err) =  _git "ls-remote $origin";
    for (split /\n/, $out) {
        my ($id, $path) = ($_ =~ /^(\S+)\s+(\S+)$/);
        $refs{$path}++;
        $refs{$id}++;
    }
    return %refs;
}

sub _git_tags {
    my %t = ();
    my $current = slurp_file '.git/HEAD';
    chomp $current;
    my ($out, $err) = _git "show-ref --tags";
    if (my $err = $@) {
       die "$err" if $out;
    }
    for (split /\n/, $out)
    {
        chomp;
        if (/^(\S+)\s+refs\/tags\/(.*)$/) {
            my $ref = $1;
            my $tag = $2;

            $t{$tag} = 0;
            $t{$tag}++ if $current eq $ref;
        }
    }
    return %t;
}

sub _git_ls {
    my @type = map (" --${_} ", @_);
    my ($out, $err) = _git "ls-files @type";

    return map (($_ => 1),
            grep { defined }
            grep { length  }
            split /\n/, $out || '');
}

sub _git_revision {
    my $rev = slurp_file '.git/HEAD';
    chomp $rev;
    $rev =~ s/^ref:\s+//;
    $rev =~ s{^.*/}{};
    $rev;
}

sub _git_revision_resolve {
    my $rev = shift;
    (my $remote, undef) = _git "config branch.'$rev'.remote";
    (my $merge,  undef) = _git "config branch.'$rev'.merge";
    chomp $remote;
    chomp $merge;
    $merge =~ s{^.*/}{};
    return sprintf "%s:$merge", ($remote eq '.' ? "TAG" : "BRANCH");
}

sub _git_stash_list {
    my ($out, $err) = _git "stash list";
    return (split /\n/, $out || '');
}

sub _git_diff {
    my ($since, $until) = @_;

    my %map = (
        'M' => 'MODIFIED',
        'D' => 'DELETED',
        'A' => 'ADDED',
        'T' => 'MODE CHANGE',
        'C' => 'COPIED',
        'R' => 'RENAMED',
        'U' => 'UNMERGED',
        'X' => 'UNKNOWN',
    );

    my ($out, $err) = _git "diff --name-status --diff-filter='ACDMRTUXB*' $since..$until";
    my @diff= grep { length } map { s/^\s+//; s/\s+$//; $_ } split /\n/, $out || '';

    my %changes = ();

    for (@diff) {
        my ($change, $file) = /^(\S)\s*(\S*)$/;
        $changes{$file} ||= $map{$change} || 'UNKNOWN';
    }
    return %changes;
}

sub _git_check {
    my ($dir, $git) = @_;

    my $repos  = $git->{repos} || $git->{repository};
    $git->{repos} = $repos; # set {'repos'}

    my $remote = $git->{remote} || 'origin';
    my $origin = $git->{origin};
    my $branch = $git->{branch} || 'master';
    my $tag    = $git->{tag} ||'';
    my @ignore = Conform::Core::comma_or_arrayref $git->{ignore} || [];
	
    push @ignore, '.conform/';

    my $tag_prefix    = exists $git->{prefix} ? $git->{prefix} : "deploy_tag_";
    my $branch_prefix = exists $git->{prefix} ? $git->{prefix} : "deploy_branch_";

    $tag_prefix ||= '';
    $branch_prefix ||= '';

    my $max_untracked_files = $git->{max_untracked_files};
    my $track_local_changes = $git->{track_local_changes};

    $max_untracked_files = GIT_MAX_UNTRACKED_FILES       unless defined $max_untracked_files;
    $track_local_changes = GIT_MAX_TRACKED_LOCAL_CHANGES unless defined $track_local_changes;

    # set 'info' HASH. This is a return value
    my $info = $git->{info} ||= { };

    my $no_checkout = $git->{no_checkout};
    my $no_merge    = $git->{no_merge};
    my $no_gc       = $git->{no_gc};

    my $status = GIT_NO_CHANGES;

    $dir ||= '';
    $dir =~ m{^/} and $dir !~ m/(\.\/|\/\.)/
        or die "directory is not absolute: $dir";

    $origin or die "origin not specified";

    if ($no_checkout) {
        note "Not checking out $repos due to --git-no-checkout";
        return $status if $no_checkout;
    }

    # clone (deep) repository if '$dir' does not exists
    unless (-d $dir) {
	if ($origin =~ m{^/}) {
            note "Cloning $repos from $origin/$repos";
            _git "clone $origin/$repos $dir", timeout => 300;
        } else {
            note "Cloning $repos from $origin";
            _git "clone $origin:$repos $dir", timeout => 300;
        }
        $status = GIT_CHECKED_OUT;
    }

    # TODO: add submodule support

    chdir $dir or die "$!";

    die "directory is not a valid git repository: $dir"
        unless -d ".git";

    # Add some gitignore's (Template taken from empty git clone '.git/info/exclude')
    text_install '.git/info/exclude', <<EOIGNORE, undef, { rcs => 0, quiet => 1 };
# git-ls-files --others --exclude-from=.git/info/exclude
# Lines that start with '#' are comments.
# For a project mostly in C, the following would be a good set of
# exclude patterns (uncomment them if you want to use them):
# *.[oa]
# *~
@{[ join "\n", map { s/^\s+//; s/\s+$//; $_ } @ignore ]}
EOIGNORE

    # make sure we fetch everything possible
    trace "fetching remote updates";
    # clean up first
    if ($no_gc) {
        trace "skipping gc... use --git-gc=$repos to enable"
    } else {
        _git "gc", timeout => 300;
    }
    _git "fetch $remote";
    _git "fetch ";
    _git "fetch --tags";

    dir_check "$dir/.conform";

    # return unless we just "clone(d)" a repos
    return $status if ($no_merge && !($status & GIT_CHECKED_OUT));

    # grab the current state of the git repos
    my %files          = _git_ls (qw(exclude-standard));
    my %local_modified = _git_ls (qw(modified exclude-standard));
    my %local_deleted  = _git_ls (qw(deleted  exclude-standard));
    my %local_added    = _git_ls (qw(others   exclude-standard));
    my %local_unmerged = _git_ls (qw(unmerged exclude-standard));


    my %local_branches  = _git_local_branches;
    my %remote_branches = _git_remote_branches;

    # Even though local changes are bad. We allow some :)
    if (($max_untracked_files >= 0) && keys %local_added > $max_untracked_files) {
        die sprintf "Too many untracked local files for $repos. Please add the these to '.gitignore': \n%s\nMAX UNTRACKED FILES = %s",
            join ("\n", keys %local_added), $max_untracked_files;
    }

    # We add these so that we can add them to the local 'stash' prior to checkout/merge
    _git "add '$_'" for sort { length $a <=> length $b } keys %local_added;

    trace "git stash'ing local changes (if any)";
    _git "stash";

    # we only keep '$track_local_changes' amount of 'stash(s)'
    my @list = _git_stash_list;
    for (my $i = $#list; $i > $track_local_changes; $i--) {
        _git "stash drop stash\@{$i}";
    }

    my $old_local_rev = _git_revision;
    my $old_rev =       _git_revision_resolve $old_local_rev;

    my $local_branch = "${branch_prefix}${branch}";
    my $local_tag    = "${tag_prefix}${tag}" if $tag;

    # We create a local tracking branch for both remote 'branches' and 'tags'.
    # It might be a better idea to have a detached 'HEAD' but this seems to work well
    # for stash/merge/reset operations.
    # While you can specify a 'branch' and a 'tag', 'tag' always wins.
    # Also there is always a 'master' branch (remote and local)
   
    if (!exists $local_branches{$local_branch} and $local_branch ne 'master' ) {
        note "Creating local tracking branch for remote branch: $local_branch -> $branch";
        _git "branch $local_branch --track $remote/$branch";
    }

    if ($tag and !exists $local_branches{$local_tag} and $local_tag ne 'master') {
        note "Creating local tracking branch for tag: $local_tag -> $tag";
        _git "branch $local_tag --track refs/tags/$tag";
    }

    $tag ? _git "checkout -q -f $local_tag"
         : _git "checkout -q -f $local_branch";


    # Grab a diff between old and new
    my %diff;
    unless ($status & GIT_CHECKED_OUT) {
        %diff = _git_diff $old_local_rev, ($tag ? "refs/tags/$tag" : "$remote/$branch");
    }

    # If this is a branch then merge remote with local
    # (n.b we are going through the steps of 'git pull'
    # but this gives us more control
   
    unless ($tag) {
        _git "merge $remote/$branch";
    }

    my $new_local_rev = _git_revision;
    my $new_rev = _git_revision_resolve $new_local_rev;

    # flag 'UPDATED' in the return value
    unless ($status & GIT_CHECKED_OUT) {
        $status |= GIT_UPDATED if $old_local_rev ne $new_local_rev or keys %diff;
    }

    # populate %info
    $info->{files} = \%files;
    $info->{local_modified} = \%local_modified;
    $info->{local_deleted} =  \%local_deleted;
    $info->{local_added} = \%local_added;
    $info->{local_unmerged} = \%local_unmerged;
    $info->{old_rev} = $old_rev;
    $info->{new_rev} = $new_rev;
    $info->{old_local_rev} = $old_local_rev;
    $info->{new_local_rev} = $new_local_rev;
    $info->{diff} = \%diff;

    return $status;
}

my @servers = qw(git01.syd);
my $git_checkout_path = "/opt";

sub GIT
    : Action
    : Args()
    : Desc(Checkout GIT repositories) {

    debug "GIT (%s)", dump($_[0]);
    local @ARGV = @ARGV;

    my $args = shift;
    my ($path, $to_checkout) = %$args;
    my $agent = pop;

    $path = $path =~ m{^/} ? $path : "$git_checkout_path/$path";

    my @no_checkout;
    my @no_gc;
    my @no_merge;
    my @no_conform_cfg;
    my @no_machine_cfg;
    my @no_autorun;

    my @checkout;
    my @gc;
    my @merge;
    my @conform_cfg;
    my @machine_cfg;
    my @autorun;

    GetOptions(
        'git-no-checkout=s'    => \@no_checkout,
        'git-no-merge=s'       => \@no_merge,
	    'git-no-gc=s'          => \@no_gc,
        'git-no-machine-cfg=s' => \@no_machine_cfg,
        'git-no-conform-cfg=s' => \@no_conform_cfg,
        'git-no-autorun=s'     => \@no_autorun,

        'git-checkout=s'       => \@checkout,
        'git-merge=s'          => \@merge,
	    'git-gc=s'             => \@gc,
        'git-conform-cfg=s'    => \@conform_cfg,
        'git-machine-cfg=s'    => \@machine_cfg,
        'git-autorun=s'        => \@autorun,
    );

    my %git_repos_groups;
    no strict 'refs';

    no strict 'refs';
    our (%m, $iam, $_path, $_class, $_repository);
    *m = $agent->nodes;
    $iam = $agent->iam;
    
    my %groups = map { %$_ } grep { ref $_ eq 'HASH' } i_isa_fetchall ('Git_repos');

    for my $group (keys %groups)
    {	
        $git_repos_groups{$group} = {
            %{$groups{$group}},
        }
    }

    my $repos      = $to_checkout->{'repos'} || $to_checkout->{'repository'};
    my $group      = $to_checkout->{'group'};
    my $origin     = $to_checkout->{'origin'} || $git_repos_groups{$group}{server};
    my $user       = $git_repos_groups{$group}{user} || "${group}-git";
    my $rev        = $to_checkout->{'rev'} || '';
    my $tag        = $to_checkout->{'tag'} || '';
    my $branch     = $to_checkout->{'branch'} || 'master';
    my $no_autorun = $to_checkout->{'no_autorun'} || 0;
    my $no_conform_cfg = $to_checkout->{'no_conform_cfg'} || 0;
    my $no_machine_cfg = $to_checkout->{'no_machine_cfg'} || 0;
    my $no_merge   = $to_checkout->{'no_merge'};
    my $no_checkout= $to_checkout->{'no_checkout'};
    my $no_gc      = $to_checkout->{'no_gc'} || 1;
    my $prefix     = $to_checkout->{'prefix'};
    my $ignore     = $to_checkout->{'ignore'};
    my $remote     = $to_checkout->{'remote'} || 'origin';
    my $on_checkout = $to_checkout->{'on_checkout'} || $to_checkout->{'on_clone'};
    my $on_update   = $to_checkout->{'on_update'};
    my $max_untracked_files = $to_checkout->{'max_untracked_files'};
    my $track_local_changes = $to_checkout->{'track_local_changes'};

    unless ($repos) {
        warn "No repos set in 'GIT' configuration for $path";
        return;
    }

    if (i_isa "Disable_git_$repos" ) {
        warn "GIT module $repos disabled\n";
        return;
    }

    $prefix = "" if i_isa 'Dev' and !defined $prefix;

    $path = sprintf "%s/%s", $git_checkout_path, $path
                unless $path =~ m{^/};

    trace "Checking out $repos to $path";

    for my $check (
         [ \@no_autorun,     \@autorun,     \$no_autorun ],
         [ \@no_conform_cfg, \@conform_cfg, \$no_conform_cfg ],
         [ \@no_machine_cfg, \@machine_cfg, \$no_machine_cfg ],
         [ \@no_merge,       \@merge,       \$no_merge ],
         [ \@no_checkout,    \@checkout,    \$no_checkout ],
         [ \@no_gc,          \@gc,          \$no_gc]) {
        
        my ($no_override, $override, $value) = @$check;
        if ($$value) {
            if ((grep /^$repos$/, @$override) || (@$override == 1 and $override->[0] eq '*')) {
                $$value = 0
            }

        } else {
            if ((grep /^$repos$/, @$no_override) || (@$no_override == 1 and $no_override->[0] eq '*')) {
                $$value = 1;
            }
        }
    }

    $tag = $rev if $rev;
    $origin = "$user\@$origin"
        if $origin and $origin !~ m{^/};

    $group ||= $repos; 
    unless ($origin) {
        warn "Could not find server for GIT repository group ($group)";
        return;
    }

    if ($origin =~ m{^/} and ! -d "$origin/$repos") {
        warn "Local origin directory ($origin/$repos) does not exist";
        next return;
    }

    # make a couple of local variables to be used by conform.cfg
    local ($_path, $_repository, $_class) = ($path, $repos, "GIT_${group}_$repos");

    $path =~ s,//+,/,g;
    $path =~ s,/+$,,g;
    my @path = split /\//, $path;
    my $dir = pop @path;
    my $base = join('/', @path);

    unless ($dir) {
        die "Bad path: $dir";
    }

    if ($base) {
        mkpath($base, 0, 0755);
        chdir "$base"
            or die "Couldn't create directory $base";
    }

    my $info = { };

    my $status = _git_check "$base/$dir" => {
                    repos  => $repos,
                    dir    => "$base/$dir",
                    origin => $origin,
                    remote => $remote || 'origin',
                    branch => $branch,
                    tag    => $tag,
                    no_merge => $no_merge,
                    no_checkout => $no_checkout,
                    no_gc  => $no_gc,
                    ( defined $prefix ? ('prefix' => $prefix ) : () ),
                    ignore => $ignore,
                    info   => $info,
                    track_local_changes => $track_local_changes,
                    max_untracked_files => $max_untracked_files,
                   
                 };


    trace "NO CHANGES"  if $status == GIT_NO_CHANGES;
    trace "CHECKED_OUT" if $status & GIT_CHECKED_OUT;
    trace "UPDATED"     if $status & GIT_UPDATED;


    note sprintf "Processing GIT module '$repos:$info->{new_rev}' in '$base/$dir' - %s", ($status & GIT_CHECKED_OUT) ? "Checked Out" : "Updated"
        unless $no_checkout || $no_merge;

    for my $type (qw(MODIFIED DELETED UNMERGED ADDED)) {
        if (keys %{$info->{"local_@{[lc $type]}"}}) {
            note "LOCAL $type: $_" for (keys %{$info->{"local_@{[lc $type]}"}});
        }
    }

    if ($status & GIT_UPDATED || $status & GIT_CHECKED_OUT) {
        for (keys %{$info->{diff}}) {
            note sprintf " %s|%s|%s|%s|%s|%s",
                $repos,
                $info->{diff}{$_},
                $_,
                $info->{old_rev},
                $info->{new_rev},
                $origin;
        }
    }

    unless ($no_autorun || $no_machine_cfg) {
        # machines.cfg should not do anything other than modify the "machines" %m hash.
        # this is mostly here to maintain functionality, one GIT module can require another.
        for my $config ("$path/machines.cfg") {
            if (-f $config) {
                $m{$iam}{ISA}{$_class} = 1;
                trace "executing $path/machines.cfg";
                do $config;
                die "$config: $@" if $@;
                $m{$_class} ||= {};
            }
        }
    }

    my %conform_cfg = ();

    unless ($no_autorun || $no_conform_cfg) {
        # conform.cfg files are executed after all GIT modules have been checked out,
        # so we can do priority based execution.
        for my $config ("$path/conform.cfg") {
            if (-f $config) {
                # stash details away for later
                my $prio = exists $to_checkout->{prio}
                            ? $to_checkout->{prio} + 125
                            : 125;

                $conform_cfg{$config} = {
                    cfg    => $config,
                    prio   => $prio,
                    order  => $order++,
                    path   => $_path,
                    repository => $_repository,
                    class  => $_class."_conformcfg",
                    ':depend' => { name => 'GIT' },
                };
                Action 'Conform_module', $conform_cfg{$config};
            }
        } 
    }

    my @commands;

	$status |= GIT_CHECKED_OUT if -f "$path/.conform/CHECKED_OUT";
	$status |= GIT_UPDATED     if -f "$path/.conform/UPDATED";

	$on_checkout = $on_update if $on_update and !$on_checkout;

    CALLBACK: for ([ 'CHECKED_OUT', GIT_CHECKED_OUT, $on_checkout ],
                   [ 'UPDATED',     GIT_UPDATED,     $on_update   ]) {

        my ($check, $type, $callback) = @$_;

        unless (defined $callback) {
            unlink "$path/.conform/$check";
            next CALLBACK;
        }

        if (($status & $type) && $callback) {

            file_touch  "$path/.conform/$check";

            if (my $ref = ref $callback) {
                $ref eq 'ARRAY' and do {
                    for (@$callback) {
                        s/\$path/$_path/g;
                        s/^Q:// ? (Action 'QCmd', $_) : push @commands, $_;
                    }
                };
                $ref eq 'CODE' and do {
                    push @commands, $callback;
               };
           } else {
               $callback =~ s/\$path/$_path/g;
               $callback =~ s/^Q:// ? Action 'QCmd', $_, $callback : push @commands, $callback;
           }

        }

	    Action 'QCmd', "rm -f $path/.conform/$check" if -f "$path/.conform/$check";

    }

    for (@commands) {
        ref $_ eq 'CODE'
            ? $_->()
            : command $_
    }
}

1;
