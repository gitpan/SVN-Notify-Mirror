package SVN::Notify::Mirror;
use strict;

BEGIN {
    use vars qw ($VERSION @ISA $SVN_BINARY);
    $VERSION     = 0.01;
    @ISA         = qw (SVN::Notify);
}

sub prepare {
    my $self = shift;
    $self->prepare_recipients;
}

sub execute {
    my ($self) = @_;
    my $to = $self->{to} or return;
    my $repos = $self->{repos_path} or return;
    my $svn_binary = $self->{svn_binary} || '/usr/local/bin/svn';
    $self->_cd_run(
        $to,
	$svn_binary, 'update',
        -r => $self->{revision},
    );
}

sub _cd_run {
    my $self = shift;
    my $path = shift;
    chdir ($path) or die "Couldn't CD to $path: $!";
    (system { $_[0] } @_) == 0 or die "Running [@_] failed with $?: $!";
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

=head1 DESCRIPTION

Keep a local directory in sync with a portion of a Subversion repository.
Typically used to keep a development web server in sync with the changes
made to the repository.

NOTE: because 'svn export' is not able to be consistently updated, the
sync'd directory must be a full working copy, and if you are running
Apache, you should add lines like the following to your Apache
configuration file:

  # Disallow browsing of Subversion working copy
  # administrative directories.
  <DirectoryMatch "^/.*/\.svn/">
   Order deny,allow
   Deny from all
  </DirectoryMatch>

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
