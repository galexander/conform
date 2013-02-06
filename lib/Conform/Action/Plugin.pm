package Conform::Action::Plugin;
use Mouse;

has 'name' => ( is => 'rw', isa => 'Str');
has 'impl' => ( is => 'rw', isa => 'CodeRef' );
has 'version' => ( is => 'rw', isa => 'Str');
has 'id' => (is => 'rw', isa => 'Str');

1;
