#!/usr/bin/perl -w

package SVN::Notify::Mirror;
use strict;

BEGIN {
    use vars qw ($VERSION @ISA);
    $VERSION     = '0.02_07';
    @ISA         = qw (SVN::Notify);
}

__PACKAGE__->register_attributes(
    'ssh_host'     => 'ssh-host=s',
    'ssh_user'     => 'ssh-user:s',
    'ssh_tunnel'   => 'ssh-tunnel:s',
    'ssh_identity' => 'ssh-identity:s',
    'svn_binary'   => 'svn-binary:s',
    'tag_regex'    => 'tag-regex:s',
);

sub prepare {
    my $self = shift;
    $self->prepare_recipients;
    $self->prepare_files;
}

sub execute {
    my ($self) = @_;
    my $to = $self->{to} or return;
    my $repos = $self->{repos_path} or return;
    my $svn_binary = $self->{'svn_binary'} || '/usr/local/bin/svn';
    my $command = 'update';
    my @args = (
	-r => $self->{revision},
    );  	

    # need to swap function calls for backwards compatibility
    if ( defined $self->{'ssh_host'} 
    	 and not ref($self) eq 'SVN::Notify::Mirror::SSH')
    {	
	no warnings 'redefine';
	warn "Deprecated - please use SVN::Notify::Mirror::SSH directly";
	require SVN::Notify::Mirror::SSH;
	*_cd_run = \&SVN::Notify::Mirror::SSH::_cd_run;
    }

    # deal with the possible switch case
    if ( defined $self->{'tag_regex'} ) {
	$command = 'switch';
	my $regex = $self->{'tag_regex'};
	my ($tag) = grep /$regex/, @{$self->{'files'}->{'A'}};
	$tag =~ s/^.+\/tags\/(.+)/$1/;
	return unless $tag;
	my $return = $self->_cd_run(
	    $to,
	    $svn_binary,
	    'info',
	);
	if ( $return =~ m/^URL: (.+\/tags\/).+$/m ) {
	    my $url = $1;
	    $tag = $url.$tag;
	}
	push @args, $tag;
    }

    print $self->_cd_run(
	$to,
	$svn_binary,
	$command,
	@args,
    );
}

sub _cd_run {
    my ($self, $path, $binary, $command, @args) = @_;
    my $message;
    my $cmd ="$binary $command " . join(" ",@args);

    chdir ($path) or die "Couldn't CD to $path: $!";

    open my $RUN, '-|', $cmd
      or die "Running [$cmd] failed with $?: $!";
    while (<$RUN>) {
	$message .= $_;
    }
    close $RUN;
    return $message;
}

1;

__END__
########################################### main pod documentation begin ##

=head1 NAME

SVN::Notify::Mirror - Keep a mirrored working copy of a repository path

=head1 SYNOPSIS

Use F<svnnotify> in F<post-commit>:

  svnnotify --repos-path "$1" --revision "$2" \
   --handler Mirror --to "/path/to/www/htdocs" \
   [--svn-binary /full/path/to/svn] \

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

Used for mirrors on some other box, e.g. a web server in a DMZ
network.  See L<SVN::Notify::Mirror::SSH> or L<SVN::Notify::Mirror::Rsync>
for more details.

=over 4

=head1 AUTHOR

John Peacock <jpeacock@cpan.org>

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.


=head1 SEE ALSO

L<SVN::Notify>, L<SVN::Notify::Config>

=cut

############################################# main pod documentation end ##
