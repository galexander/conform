package Conform::Util::File::Digest;
use base 'Exporter';
use strict;
use Digest::SHA;
use OIE::Utils qw(text_install slurp_file);

our @EXPORT_OK = qw(
    sha_digest
    sha_digest_save
    sha_digest_read
);

sub sha_digest {
    my $file = shift;
    my $sha  = Digest::SHA->new();
    $sha->addfile($file);
    my $hexdigest = $sha->clone->hexdigest;
    my $b64digest = $sha->clone->b64digest;
    # padding
    while (length($b64digest) % 4) { $b64digest .= '='; }
    return { hex => $hexdigest, b64 => $b64digest };
}

sub sha_digest_save {
    my $file = shift;
    my $sha  = shift;
    my $sha_file = $file;
    $sha_file .= '.sha'
        unless $sha_file =~ /\.sha$/;

    $sha ||= sha_digest $file;

    text_install $sha_file, sprintf "hex:%s\nb64:%s",
                                @{$sha}{'hex', 'b64'}
                                    or die "error print: $sha_file $!";
}

sub sha_digest_read {
    my $file = shift;
    my $sha_file = $file;
    $sha_file .= '.sha'
        unless $sha_file =~ /\.sha$/;

    my $sha = {};
    if (-f $sha_file) {
        for (slurp_file $sha_file) {
            /^(\S+):(\S+)$/ and do {
                $sha->{$1} = $2;
            };
        }
    }
    return $sha;
}

1;
