# Class: mediawiki::app
#
class mediawiki::app {
  vcsrepo { '/srv/mediawiki/w':
    ensure   => present,
    provider => git,
    source   => 'https://gerrit.wikimedia.org/r/p/mediawiki/core.git',
    revision => 'e01f8d3c948fac6c44e06471822427d7d00df88a',  # temp local branch, See LP bug 1430550
    owner    => 'www-data',
    group    => 'www-data',
  }
}

# vim:sw=2:ts=2:expandtab:textwidth=79
