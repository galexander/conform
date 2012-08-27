package Conform::Site::API;
use Mouse::Role;
use strict;

requires 'version';
requires 'uri';
requires 'root';
requires 'dir_list';
requires 'file_open';
requires 'file_close';
requires 'nodes';
requires 'classes';
requires 'tasks';
requires 'actions';
requires 'vars';


1;
