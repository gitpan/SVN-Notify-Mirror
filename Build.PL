use Module::Build;
# See perldoc Module::Build for details of how this works

Module::Build->new
    ( module_name     => 'SVN::Notify::Mirror',
      license         => 'perl',
      auto_features   => {
	  ssh_support => { 
	      description => "Use remote mirrors via ssh",
	      requires    => {Net::SSH => 0.08 }
	  },
      },
    )->create_build_script;
