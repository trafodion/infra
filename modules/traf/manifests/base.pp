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

  group { 'sudo':
    ensure => present,
  }
  file { "/etc/sudoers.d/sudo_group":
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0440',
    content => '%sudo ALL=(ALL) NOPASSWD: ALL',
  }
  group { 'admin':
    ensure => present,
  }

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

  # install packages on all machines
  package { $::traf::params::packages:
    ensure => present
  }

  include pip
  package { 'virtualenv':
    ensure   => '1.11.6',
    provider => pip,
    require  => Class['pip'],
  }
  package { 'gevent':
    ensure   => '1.1.1',
    provider => pip,
    require  => Class['pip'],
  }
  package { 'eventlet':
    ensure   => '0.15.2',
    provider => pip,
    require  => Class['pip'],
  }
  package { 'kazoo':
    ensure   => '2.2.1',
    provider => pip,
    require  => Class['pip'],
  }


#  file { '/usr/local/bin/useObjectStorage.sh':
#    ensure  => file,
#    owner   => 'root',
#    group   => 'root',
#    mode    => '0750',
#    content => template('traf/useObjectStorage.sh.erb'),
#  }

  file { '/usr/local/bin/cronic':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/traf/cronic',
  }

  if ($install_users) {
    package { $::traf::params::user_packages:
      ensure => present
    }

    realize (
      User::Virtual::Localuser['svarnau'],
      User::Virtual::Localuser['alchen'],
    )
  }

  # Use upstream puppet and pin version
  if ($::osfamily == 'Debian') {
    apt::source { 'puppetlabs':
      location   => 'http://apt.puppetlabs.com',
      repos      => 'main',
      key        => '47B320EB4C7C375AA9DAE1A01054B7A24BD6EC30',
      key_server => 'pgp.mit.edu',
    }
    if $::puppetversion =~/^3/ {
      $pinfile = 'puppet:///modules/traf/00-puppet3.pref'
    } else {
      $pinfile = 'puppet:///modules/traf/00-puppet2.pref'
    }

    file { '/etc/apt/preferences.d/00-puppet.pref':
      ensure  => present,
      owner   => 'root',
      group   => 'root',
      mode    => '0444',
      source  => $pinfile,
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
