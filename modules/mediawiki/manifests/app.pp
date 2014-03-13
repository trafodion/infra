# Class: mediawiki::app
#
class mediawiki::app {
  vcsrepo { '/srv/mediawiki/w':
    ensure   => present,
    provider => git,
    source   => 'https://gerrit.wikimedia.org/r/p/mediawiki/core.git',
    revision => 'origin/master',
    owner    => 'www-data',
    group    => 'www-data',
  }
}

# vim:sw=2:ts=2:expandtab:textwidth=79
