package Conform::Action::Plugin;
use Mouse;

extends 'Conform::Plugin';

has 'name' => ( is => 'rw', isa => 'Str');
has 'impl' => ( is => 'rw', isa => 'CodeRef' );
has 'version' => ( is => 'rw', isa => 'Str');
has 'id' => (is => 'rw', isa => 'Str');

1;
