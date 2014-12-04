# == Class: traf::base
#
class traf::base(
  $certname = $::fqdn,
  $install_users = true
) {
  if ($::osfamily == 'Debian') {
    include apt
  }
  include traf::params
  include traf::users
  include sudoers

  file { '/etc/profile.d/Z98-byobu.sh':
    ensure => absent,
  }

  package { 'popularity-contest':
    ensure => absent,
  }

  if ($::lsbdistcodename == 'oneiric') {
    apt::ppa { 'ppa:git-core/ppa': }
    package { 'git':
      ensure  => latest,
      require => Apt::Ppa['ppa:git-core/ppa'],
    }
  } else {
    package { 'git':
      ensure => present,
    }
  }

  if ($::operatingsystem == 'Fedora') {

    package { 'hiera':
      ensure   => latest,
      provider => 'gem',
    }

    exec { 'symlink hiera modules' :
      command     => 'ln -s /usr/local/share/gems/gems/hiera-puppet-* /etc/puppet/modules/',
      path        => '/bin:/usr/bin',
      subscribe   => Package['hiera'],
      refreshonly => true,
    }

  }

  package { $::traf::params::packages:
    ensure => present
  }

  include pip
  package { 'virtualenv':
    ensure   => latest,
    provider => pip,
    require  => Class['pip'],
  }
  package { 'python-keystoneclient':
    ensure   => '0.4.1',
    provider => pip,
    require  => Class['pip'],
  }
  package { 'python-novaclient':
    ensure   => '2.17.0',
    provider => pip,
    require  => Class['pip'],
  }
  package { 'python-cinderclient':
    ensure   => latest,
    provider => pip,
    require  => Class['pip'],
  }
  package { 'python-neutronclient':
    ensure   => latest,
    provider => pip,
    require  => Class['pip'],
  }
  package { 'python-swiftclient':
    ensure   => latest,
    provider => pip,
    require  => Class['pip'],
  }
  package { 'python-glanceclient':
    ensure   => latest,
    provider => pip,
    require  => Class['pip'],
  }

  if ($install_users) {
    package { $::traf::params::user_packages:
      ensure => present
    }

    realize (
      User::Virtual::Localuser['svarnau'],
      User::Virtual::Localuser['alchen'],
      User::Virtual::Localuser['sjohnson'],
      User::Virtual::Localuser['johnstac'],
      User::Virtual::Localuser['csheedy'],
    )
  }

  # Use upstream puppet and pin to version 2.7.*
  if ($::osfamily == 'Debian') {
    apt::source { 'puppetlabs':
      location   => 'http://apt.puppetlabs.com',
      repos      => 'main',
      key        => '4BD6EC30',
      key_server => 'pgp.mit.edu',
    }

    file { '/etc/apt/preferences.d/00-puppet.pref':
      ensure  => present,
      owner   => 'root',
      group   => 'root',
      mode    => '0444',
      source  => 'puppet:///modules/openstack_project/00-puppet.pref',
      replace => true,
    }

  }

  file { '/etc/puppet/puppet.conf':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0444',
    content => template('traf/puppet.conf.erb'),
    replace => true,
  }

  exec { 'disable TCP timestamp responses':
    command  => '/sbin/sysctl -w net.ipv4.tcp_timestamps=0',
    provider => shell,
    unless   => 'if [ $(/sbin/sysctl -n net.ipv4.tcp_timestamps) = "0" ]; then exit 0; else exit 1; fi',
  }

}

# vim:sw=2:ts=2:expandtab:textwidth=79
