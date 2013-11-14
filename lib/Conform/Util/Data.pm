package Conform::Util::Data;
use base 'Exporter';
use strict;
use Storable qw(dclone);
use Conform::Util::Data::Path;

our @EXPORT_OK = qw(comma_or_arrayref list_contains data_path copy_of);

sub comma_or_arrayref {
    grep { defined $_ }
      map { ref $_ ? $_ : defined $_ ? split /\s*,\s*/, $_ : () }
      map { ref $_ eq 'ARRAY' ? @$_ : $_ } @_;
}


##
# Name: _list_contains
# Desc: check if a list contains a value
sub list_contains {
    my $needle   = pop @_;
    my $haystack = \@_;
    return grep /^\Q$needle\E$/, @$haystack;
}

sub copy_of {
    my $value = shift;
    if (ref $value) {
        return dclone $value;
    } else {
        return $value;
    }
}

sub data_path {
    my $data   = shift;
    my $lookup = shift;
    my $data_path   = Conform::Util::Data::Path->new($data, @_);
    return $data_path->get($lookup);
}

sub glue {
    my ($src_data, $src_data_path, $dst_data, $dst_data_path) = @_;

    my $src_node = data_path $src_data, $src_data_path;

}
