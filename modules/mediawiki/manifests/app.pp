# Class: mediawiki::app
#
class mediawiki::app {
  vcsrepo { '/srv/mediawiki/w':
    ensure   => present,
    provider => git,
    source   => 'https://gerrit.wikimedia.org/r/p/mediawiki/core.git',
    revision => 'origin/REL1_23',
    owner    => 'www-data',
    group    => 'www-data',
  }
}

# vim:sw=2:ts=2:expandtab:textwidth=79
