package Runtime::Tester;
use parent 'Conform::Runtime::Plugin';
use strict;
use Data::Dumper;

sub Foo_Task {
	print "Executing foo\n";
	print Dumper(\@_);
}
	

sub Bar : Task {
	print "Executing bar\n";
	print Dumper(\@_);
}

sub File_install : Action {

}

1;
