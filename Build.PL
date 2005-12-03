use Module::Build;
# See perldoc Module::Build for details of how this works

my $class = Module::Build->subclass
(
    class => 'JPEACOCK::Builder',
    code => q{
	sub ACTION_dist{
	    my $self = shift;
	    $self->do_system('svk log -x | gnuify-changelog.pl > Changes');
	    $self->SUPER::ACTION_dist();
	}
    }
);

my $mb = $class->new
    ( module_name     => 'SVN::Notify::Mirror',
      license         => 'perl',
      requires        => {
	  'Module::Build' => 0.2611,
      },
      auto_features   => {
	  ssh_support => { 
	      description => "Use remote mirrors via ssh",
	      requires    => {Net::SSH => 0.08 }
	  },
	  config_support => {
	      description => "Use compact YAML script",
	      requires    => {SVN::Notify::Config => 0.06}
	  },
      },
      PL_files => { 
	  't/002_config.t.PL' =>
	  ['t/testconfig','t/002_config.t','t/002_config'],
	  't/003_sshtest.t.PL' => 't/003_sshtest.t',
      },
      add_to_cleanup =>
	  ['t/test-repos', 't/wc-*',],
    );

if ( $mb->feature('ssh_support') ) {
    $mb->notes( sshtests => 1 ) if
    	$mb->y_n(
    "Do you want to run the SSH tests?\n".
    "(see the README for details)",'N');
}

$mb->create_build_script;
