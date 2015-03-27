# Class: mediawiki::app
#
class mediawiki::app {
  vcsrepo { '/srv/mediawiki/w':
    ensure   => present,
    provider => git,
    source   => 'https://gerrit.wikimedia.org/r/p/mediawiki/core.git',
    revision => 'ffb94c5ad233936e641171fbb8abb3a08ef95bb4',  # temp local branch, See LP bug 1430550
    owner    => 'www-data',
    group    => 'www-data',
  }
}

# vim:sw=2:ts=2:expandtab:textwidth=79
