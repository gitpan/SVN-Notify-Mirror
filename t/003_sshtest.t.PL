use Module::Build;
my $filename = shift;

my $mb = Module::Build->current();

if ( $mb->feature('ssh_support') and $mb->notes('sshtests') ) {
    open my $FILE, '>', $filename;
    print {$FILE} <<"EOF";
require "t/coretests.pm";

reset_all_tests();
run_tests("svnnotify", 'ssh-host' => 'localhost' );
EOF
    close $FILE;
}
