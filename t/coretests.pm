#!/usr/bin/perl 
use Test::More qw(no_plan);
use Cwd;
our $PWD = getcwd;
our $repos_path = "$PWD/t/test-repos";

$repos_history = [
    {}, # no files exist at rev 0
    {
	'wc-trunk' => { # files created on trunk at rev 1
	    file1 => 6,
	    dir1  => {},
	},
	'wc-branch' => {}, # branch created on rev 1
    },
    {
	'wc-trunk' => {
	    file1 => 6,
	    dir1  => {},
	},
	'wc-branch' => { # branch copied from trunk on rev 2
	    file1 => 6,
	    dir1  => {},
	},
    },
    {
	'wc-trunk' => {
	    file1 => 6,
	    dir1  => {}
	},
	'wc-branch' => { # branch changed on rev 3
	    file1 => 6,
	    file2 => 6,
	    dir1  => {
		file3 => 6
	    },
	},
    },
    {
	'wc-trunk' => { # branch merged to trunk on rev 4
	    file1 => 6,
	    file2 => 6,
	    dir1  => {
		file3 => 6
	    },
	},
	'wc-branch' => { 
	    file1 => 6,
	    file2 => 6,
	    dir1  => {
		file3 => 6
	    },
	},
    },
];

$changes = [
    {}, # zeroth has nothing
    {}, # nothing to see here, either
    {}, # nor here, for that matter
    { 'dir1/file3' => 'A',
	'file2'      => 'A', },
    { 'dir1/file3' => 'A',
	'file2'      => 'A', },
];

sub reset_all_tests {
    create_test_repos();
    create_test_wcs();
    reset_test_wcs();
}

# Create a repository fill it with sample values the first time through
sub create_test_repos {
    unless ( -d $repos_path ) {

	system(<<"") == 0 or die "system failed: $?";
svnadmin create $repos_path

	system(<<"") == 0 or die "system failed: $?";
svnadmin load --quiet $repos_path < ${repos_path}.dump

    }
}

# Create test WC's before proceeding with tests the first time
sub create_test_wcs {
    unless ( -d "$PWD/t/wc-trunk" ) {

	system(<<"") == 0 or die "system failed: $?";
svn checkout -q -r1 file://$repos_path/trunk $PWD/t/wc-trunk

	system(<<"") == 0 or die "system failed: $?";
svn checkout -q -r2 file://$repos_path/branches/branch1 $PWD/t/wc-branch

    }
}

# Reset the working copies
sub reset_test_wcs {
    system("svn update -q -r1 $PWD/t/wc-trunk") == 0
      or die "system failed: $?";

    system("svn update -q -r2 $PWD/t/wc-branch") == 0
      or die "system failed: $?";
}

sub run_tests {
    my $command = shift;
    my %args = @_;
    my $TESTER;

    # Common to all tests
    $args{'repos-path'} = $repos_path;
    $args{'handler'}    = 'Mirror';

    # Test t/wc-trunk
    $args{'to'}       = "$PWD/t/wc-branch";

    $args{'revision'} = 2;
    _test('^At revision (\d+)\.', $changes->[2], $command, %args);
    _compare_directories(2);

    $args{'revision'} = 3;
    _test('^Updated to revision (\d+)\.', $changes->[3], $command, %args);
    _compare_directories(3);

    # Test the t/wc-trunk
    $args{'to'}       = "$PWD/t/wc-trunk";

    $args{'revision'} = 4;
    _test('^Updated to revision (\d+)\.', $changes->[4], $command, %args);
    _compare_directories(4);
}

sub _test {
    my ($regex, $expected, $command, %args) = @_;
    my $test = {};

    open $TESTER, '-|', _build_command($command, %args);
    while (<$TESTER>) {
	chomp;
	if ( /$regex/ ) {
	    ok ( $1 == $args{revision} , "Updated to correct revision: "
	    	. $args{revision} );
	}
	else {
	    my ($status, $target) = split;
	    $test->{$target} = $status;
	}
    }
    is_deeply($test, $expected, "Correct files updated at rev: " . 
    	$args{revision});
    close $TESTER;
}

sub _build_command {
    my ($command, %args) = @_;
    my @commandline = split " ", $command;

    if ( $command =~ /svnnotify/ ) {
	# hate to hardcode this, but what else can we do
	foreach my $key ( keys(%args) ) {
	    push @commandline, "\-\-$key", $args{$key};
	}
    }
    else {
	push @commandline, $args{'repos-path'}, $args{'revision'};
    }
    return @commandline;
}

sub _compare_directories {
    my $rev = shift;
    my $history = $repos_history->[$rev];
    my $this_rev = {};

    foreach my $dir ( keys %$history ) {
	$this_rev->{$dir} = _scan_dir("t/$dir");
    }
	
    is_deeply($history, $this_rev, "Directories are consistent at rev: $rev");
}

sub _scan_dir {
    my ($dir) = @_;
    my $fsize;
    my $this_rev = {};

    opendir my($DIR), $dir;
    my @directory = grep !/^\..*/, readdir $DIR;
    closedir $DIR;

    foreach my $file ( @directory ) {
	if ( -d "$dir/$file" ) {
	    $this_rev->{$file} = _scan_dir( "$dir/$file" );
	}
	elsif ( ( -f "$dir/$file" )  && ( my $size = -s "$dir/$file" ) ) {
	    $this_rev->{$file} = $size;
	}
    }
    return defined $this_rev ? $this_rev : {};
}

1; # magic return
