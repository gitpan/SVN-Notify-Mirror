#!/usr/bin/perl -w

package SVN::Notify::Mirror;
use strict;

BEGIN {
    use vars qw ($VERSION @ISA $SVN_BINARY);
    $VERSION     = "0.01_05";
    $VERSION     = eval $VERSION;
    @ISA         = qw (SVN::Notify);
}

__PACKAGE__->register_attributes(
    ssh_host     => 'ssh_host=s',
    ssh_user     => 'ssh_user:s',
    ssh_tunnel   => 'ssh_tunnel:s',
    ssh_identity => 'ssh_identity:s',
);


sub prepare {
    my $self = shift;
    $self->prepare_recipients;
}

sub execute {
    my ($self) = @_;
    my $to = $self->{to} or return;
    my $repos = $self->{repos_path} or return;
    my $svn_binary = $self->{svn_binary} || '/usr/local/bin/svn';
    my $command = 'update';

    if ( defined $self->{ssh_host} ) {
	$self->_ssh_run(
	    $to,
	    $svn_binary, $command,
	    -r => $self->{revision},
	);
    }
    else {
	$self->_cd_run(
	    $to,
	    $svn_binary, $command,
	    -r => $self->{revision},
	);
    }
}

sub _cd_run {
    my ($self, $path) = (shift, shift);
    chdir ($path) or die "Couldn't CD to $path: $!";
    (system { $_[0] } @_) == 0 or die "Running [@_] failed with $?: $!";
}

sub _ssh_run {
    my ($self, $path) = (shift, shift);
    eval "use Net::SSH qw(sshopen2)";
    die "Failed to load Net::SSH: $@" if $@;
    my $host = $self->{ssh_host};
    my $user = 
    	defined $self->{ssh_user} 
    	? $self->{ssh_user}.'@'.$host
	: $host;

    my $cmd  = "cd $path && " . join(" ",@_);
    if ( defined $self->{ssh_tunnel} ) {
	push @Net::SSH::ssh_options, 
		"-R3690:".$self->{ssh_tunnel}.":3690";
    }
    if ( defined $self->{ssh_identity} ) {
	push @Net::SSH::ssh_options,
		"-i".$self->{ssh_identity};
    }

    sshopen2($user, *READER, *WRITER, $cmd) || die "ssh: $!";

    while (<READER>) {
	chomp();
#	print "$_\n";
    }

    close(READER);
    close(WRITER);
}

1;

__END__
########################################### main pod documentation begin ##

=head1 NAME

SVN::Notify::Mirror - Keep a mirrored working copy of a repository path

=head1 SYNOPSIS

Use F<svnnotify> in F<post-commit>:

  svnnotify --repos-path "$1" --revision "$2" \
    --to "/path/to/www/htdocs" --handler Mirror \
   [--svn-binary /full/path/to/svn]

or better yet, use L<SVN::Notify::Config> for a more
sophisticated setup:

  #!/usr/bin/perl -MSVN::Notify::Config=$0
  --- #YAML:1.0
  '':
    PATH: "/usr/bin:/usr/local/bin"
  'path/in/repository':
    handler: Mirror
    to: "/path/to/www/htdocs"
  'some/other/path/in/repository':
    handler: Mirror
    to: "/path/to/remote/www/htdocs"
    ssh_host: "remote_host"
    ssh_user: "remote_user"
    ssh_tunnel: "10.0.0.2"
    ssh_identity: "/home/user/.ssh/id_rsa"

=head1 DESCRIPTION

Keep a directory in sync with a portion of a Subversion repository.
Typically used to keep a development web server in sync with the changes
made to the repository.  This directory can either be on the same box as
the repository itself, or it can be remote (via SSH connection).

=head1 USAGE

Depending on whether the target is a L<Local Mirror> or a L<Remote
Mirror>, there are different options available.  All options are
available either as a commandline option to svnnotify or as a hash
key in L<SVN::Notify::Config> (see their respective documentation for
more details).

=head2 Working Copy on Mirror

Because 'svn export' is not able to be consistently updated, the
sync'd directory must be a full working copy, and if you are running
Apache, you should add lines like the following to your Apache
configuration file:

  # Disallow browsing of Subversion working copy
  # administrative directories.
  <DirectoryMatch "^/.*/\.svn/">
   Order deny,allow
   Deny from all
  </DirectoryMatch>
  
The files in the working copy must be writeable (preferrably owned)
by the user identity executing the hook script (this is the user 
identity that is running Apache or svnserve respectively).

=head2 Local Mirror

Used for directories local to the repository itself (NFS or other
network mounted drives count).  The only required options are:

=over 4

=item * handler = Mirror

Specifies that this module is called to process the Notify event.

=item * to = /path/to/working/copy

Specified which directory should be updated.

=back

=head2 Remote Mirror

Used for directories not located on the same machine as the
repository itself.  Typically, this might be a production web
server located in a DMZ, so special consideration must be paid
to security concerns.  In particular, the remote mirror server
may not be able to directly access the repository box.

NOTE: be sure and consult L<Remote Mirror Pre-requisites>
before configuring your post-commit hook.

=over 4

=item * ssh_host

This value is required and must be the hostname or IP address
of the remote host (where the mirror directories reside).

=item * ssh_user

This value is optional and specifies the remote username that
owns the working copy mirror.

=item * ssh_identity

This value may be optional and should be the full path to the
local identity file being used to authenticate with the remote
host. If you are setting the ssh_user to be something other than
the local user name, you will typically also have to set the
ssh_identity.

=item * ssh_tunnel

If the remote server does not have direct access to the repository
server, it is possible to use the tunneling capabilities of SSH
to provide temporary access to the repository.  This works even 
if repository is located internally, and the remote server is 
located outside of a firewall or on a DMZ.

The value passed as the ssh_tunnel should be the IP address to
which the local repository service is bound (whether that is
Apache or svnserve).  This will tunnel port 3690 from the 
repository box to localhost:3690 on the remote box.  This must
also be the way that the original working copy was checked out.

For example, see L<Remote Mirror Pre-requisites> and after step #6,
perform the following additional steps:

  # su - localuser
  $ ssh -i .ssh/id_rsa remote_user@remote_host -R3690:10.0.0.2:3690
  $ cd /path/to/mirror/working/copy
  $ svn co svn://127.0.0.1/repos/path/to/files .

where 10.0.0.2 is the IP address hosting the repository service.  
Replace C<svn://> with C<http://> if you are running Apache 
instead of svnserve.

=head2 Remote Mirror Pre-requisites

Before you can configure a remote mirror, you need to produce
an SSH identity file to use:

=over 4

=item 1. Log in as repository user

Give the user identity being used to execute the hook scripts 
(the user running Apache or svnserve) a shell and log in as 
that user, e.g. C<su - svn>;

=item 2. Create SSH identity files on repository machine

Run C<ssh-keygen> and create an identity file (without a password).

=item 3. Log in as remote user

Perform the same steps as #1, but this time on the remote machine.
This username doesn't have to be the same as in step #1, but it
must be a user with full write access to the mirror working copy.

=item 4. Create SSH identity files on remote machine

It is usually more efficient to go ahead and use C<ssh-keygen> to
create the .ssh folder in the home directory of the remote user.

=item 5. Copy the public key from local to remote

Copy the .ssh/id_dsa.pub (or id_rsa.pub if you created an RSA key)
to the remote server and add it to the .ssh/authorized_keys for
the remote user.  See the SSH documentation for instructions on
how to configure 

=item 6. Confirm configuration

As the repository user, confirm that you can sucessfully connect to
the remote account, e.g.:

  # su - local_user
  $ ssh -i .ssh/id_rsa remote_user@remote_host

This is actually a good time to either check out the working copy
or to confirm that the remote account has rights to update the
working copy mirror.  If the remote server does not have direct
network access to the repository server, you can use the tunnel
facility of SSH (see L<ssh_tunnel> above) to provide access (e.g.
through a firewall).

=back

Once you have set up the various accounts, you are ready to set
your options.

=over 4

=head1 AUTHOR

  John Peacock
  jpeacock@cpan.org

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.


=head1 SEE ALSO

L<SVN::Notify>, L<SVN::Notify::Config>

=cut

############################################# main pod documentation end ##
