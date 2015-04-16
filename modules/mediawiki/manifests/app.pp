# Class: mediawiki::app
#
class mediawiki::app {
  vcsrepo { '/srv/mediawiki/w':
    ensure   => present,
    provider => git,
    source   => 'https://gerrit.wikimedia.org/r/p/mediawiki/core.git',
    revision => 'b6cf0c596f376c1024dfd2834da2717f8f12b06a',  # temp local branch, See LP bug 1430550
    owner    => 'www-data',
    group    => 'www-data',
  }
}

# vim:sw=2:ts=2:expandtab:textwidth=79
