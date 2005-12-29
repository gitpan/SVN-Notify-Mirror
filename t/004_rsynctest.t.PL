use Module::Build;
my $filename = shift;

my $mb = Module::Build->current();

my $testscript = <<"EOF";
require "t/coretests.pm";

reset_all_tests();
run_tests("svnnotify", 'rsync-host' => 'localhost',
EOF

if ( $mb->feature('rsync_support') and $mb->notes('rsynctests') ) {
    if ( $mb->feature('ssh_support') and $mb->notes('sshtests') ) {
	$testscript .= "'rsync-ssh' => 1";
    }
    $testscript .= ');';

    open my $FILE, '>', $filename;
    print {$FILE} $testscript;
    close $FILE;
}
