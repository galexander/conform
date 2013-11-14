package Conform::Util::Deployment::MVN;
use strict;
use base 'Exporter';
use XML::LibXML;
use OIE::Utils qw(slurp_file slurp_http);
use Conform::Module::Debug qw(debug);

our @EXPORT_OK = qw(mvn_snapshot_uri);

##
# Name: _xml_elements
# Desc: get a list of xml elements by name
sub _xml_elements {
    my ($node, $name) = @_;
    my @elements = $node->getElementsByLocalName($name);
    @elements
        or die "$name not found in xml document";
    return wantarray
            ? @elements
            :\@elements;
}

##
# Name: _xml_element
# Desc: get a single xml element by name
sub _xml_element {
    my ($node, $name) = @_;
    (_xml_elements $node, $name)[0];
}

##
# Name: _mvn_metadata_artifact
# Desc: get the 'artifactId' from maven-metadata.xml
sub _mvn_metadata_artifact {
    my $dom = shift;
    my ($artifact_id) = _xml_element $dom->documentElement,
                                     'artifactId';
    return $artifact_id->textContent;
}

# Name: _mvn_metadata_vesion
# Desc: get the 'version' from maven-metadata.xml
sub _mvn_metadata_version {
    my $dom = shift;
    my ($version) = _xml_element $dom->documentElement,
                                 'version';
    return $version->textContent;
}

##
# Name: _mvn_metadata_snapshot
# Desc: get versioning/snapshot from maven-metadata.xml
sub _mvn_metadata_snapshot {
    my $dom = shift;
    my $snapshot = _xml_element $dom->documentElement,
                                'snapshot';

    my $timestamp      = _xml_element $snapshot, 'timestamp';
    my $build_number   = _xml_element $snapshot, 'buildNumber';

    return {
        timestamp => $timestamp->textContent,
        buildNumber => $build_number->textContent,
    };
}

# Name: _mvn_metadata_snapshot_versions
# Desc: get a list of snapshotVersion/snapshotVersions
#       from maven-metadata.xml
sub _mvn_metadata_snapshot_versions {
    my $dom = shift;
    my $snapshot_versions = _xml_element $dom->documentElement,
                                         'snapshotVersions';

    my @snapshot_versions = _xml_elements $snapshot_versions,
                                          'snapshotVersion';

    my @versions;
    for my $node (@snapshot_versions) {
        my ($extension)      = _xml_element $node, 'extension';
        my ($value)          = _xml_element $node, 'value';
        my ($classifier)     = _xml_element $node, 'classifier';

        push @versions, {
                            ext        => $extension->textContent,
                            version    => $value->textContent,
                            classifier => ($classifier
                                                ? $classifier->textContent
                                                : undef)
                        };
        }
        return @versions;
}

sub mvn_snapshot_uri {
    my $uri = shift;
    debug "_mvn_snapshot_uri %s\n", $uri;
    my ($ext) =  $uri =~ m{\.(\w+)$};
    (my $maven_metadata_uri = $uri) =~ s!^(.*)/.*!$1/maven-metadata.xml!g;

    debug "_mvn_snapshot_uri(metadata) %s\n", $maven_metadata_uri;
    my $metadata =  slurp_http $maven_metadata_uri, { cache => undef };
    debug "mvn metadata = %s\n", $metadata;
    my $dom = XML::LibXML->load_xml(string => $metadata);
    my $artifact = _mvn_metadata_artifact $dom;
    my $version  = _mvn_metadata_version $dom;
    my @versions = eval { _mvn_metadata_snapshot_versions $dom };
    unless (@versions) {
        my $snapshot = _mvn_metadata_snapshot $dom;
        my $snapshot_version =
                sprintf "%s-%s", $snapshot->{timestamp},
                                 $snapshot->{buildNumber};

        $version  =~ s!SNAPSHOT!$snapshot_version!;
        push @versions, {
                            ext => $ext,
                            version => $version,
                        };
    }
    for (@versions) {
        my ($snapshot_ext, $snapshot_version, $snapshot_classifier)
                = ($_->{ext}, $_->{version}, $_->{classifier});

        if ($snapshot_ext eq $ext) {
            my $name =
                defined $snapshot_classifier
                            ? (sprintf "%s-%s-%s.%s", $artifact,
                                                      $snapshot_version,
                                                      $snapshot_classifier,
                                                      $snapshot_ext)
                            : (sprintf "%s-%s.%s", $artifact,
                                                   $snapshot_version,
                                                   $snapshot_ext);

            (my $snapshot_uri= $maven_metadata_uri) =~ s{/maven-metadata.xml$}{/$name};
            return $snapshot_uri;
        }
    }
    die "could not find snapshot version for ext($ext) from $maven_metadata_uri ($uri)";
}


1;
