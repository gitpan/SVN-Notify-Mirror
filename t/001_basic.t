#!/usr/bin/perl 
require SVN::Notify;
require "t/coretests.pm";

my $SVNNOTIFY = $ENV{'SVNNOTIFY'} || SVN::Notify->find_exe('svnnotify');

BAIL_OUT("Cannot locate svnnotify binary!") unless defined($SVNNOTIFY);

reset_all_tests();
run_tests($SVNNOTIFY);
