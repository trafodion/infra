# == Class: jeepyb
#
class jeepyb (
  $git_source_repo = 'https://github.com/trafodion/jeepyb',
) {
  include mysql::python

  if ! defined(Package['python-paramiko']) {
    package { 'python-paramiko':
      ensure   => present,
    }
  }

  package { 'gcc':
    ensure => present,
  }

  # A lot of things need yaml, be conservative requiring this package to avoid
  # conflicts with other modules.
  case $::osfamily {
    'Debian': {
      if ! defined(Package['python-yaml']) {
        package { 'python-yaml':
          ensure => present,
        }
      }
    }
    'RedHat': {
      if ! defined(Package['PyYAML']) {
        package { 'PyYAML':
          ensure => present,
        }
      }
    }
    default: {
      fail("Unsupported osfamily: ${::osfamily} The 'jeepyb' module only supports osfamily Debian or RedHat.")
    }
  }

  vcsrepo { '/opt/jeepyb':
    ensure   => latest,
    provider => git,
    revision => 'master',
    source   => $git_source_repo,
  }

  exec { 'install_jeepyb' :
    command     => 'pip install /opt/jeepyb',
    path        => '/usr/local/bin:/usr/bin:/bin/',
    refreshonly => true,
    require     => Class['mysql::python'],
    subscribe   => Vcsrepo['/opt/jeepyb'],
    logoutput   => true,
  }
}
