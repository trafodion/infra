# == Class: traf::puppetmaster
#
class traf::puppetmaster (
  $sysadmins = [],
  $cloud_auto_user = "",
  $cloud_auto_passwd = "",
) {
  class { 'traf::server':
    iptables_public_tcp_ports => [4505, 4506, 8140],
    sysadmins                 => $sysadmins,
  }

  class { 'salt':
    salt_master => 'puppet.trafodion.org',
  }

  class { 'salt::master': }

  cron { 'updatepuppetmaster':
    user        => 'root',
    minute      => '*/15',
    command     => 'sleep $((RANDOM\%600)) && cd /opt/config/production && git fetch -q && git reset -q --hard @{u} && ./install_modules.sh && touch manifests/site.pp',
    environment => 'PATH=/var/lib/gems/1.8/bin:/usr/bin:/bin:/usr/sbin:/sbin',
  }

  cron { 'deleteoldreports':
    user        => 'root',
    hour        => '3',
    minute      => '0',
    command     => 'sleep $((RANDOM\%600)) && find /var/lib/puppet/reports -name \'*.yaml\' -mtime +7 -execdir rm {} \;',
    environment => 'PATH=/var/lib/gems/1.8/bin:/usr/bin:/bin:/usr/sbin:/sbin',
  }

  file { '/etc/puppet/hiera.yaml':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0555',
    source  => 'puppet:///modules/traf/puppetmaster/hiera.yaml',
    replace => true,
    require => Class['traf::server'],
  }

  file { '/var/lib/puppet/reports':
    ensure => directory,
    owner  => 'puppet',
    group  => 'puppet',
    mode   => '0750',
    }

  # Cloud admin script
  file { '/usr/local/bin/slave-ip.sh':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => template('traf/slave-ip.sh.erb'),
  }

#### Not sure if we'll use launch-node.py script
#
# Cloud credentials are stored in this directory for launch-node.py.
  file { '/root/ci-launch':
    ensure => directory,
    owner  => 'root',
    group  => 'admin',
    mode   => '0750',
    }

# For launch/launch-node.py.
  package { 'python-novaclient':
    ensure   => '2.17.0',
    provider => pip,
  }
  package { 'python-cinderclient':
    ensure   => latest,
    provider => pip,
  }
  package { 'python-paramiko':
    ensure => present,
  }
}
