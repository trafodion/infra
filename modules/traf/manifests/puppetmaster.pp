# == Class: traf::puppetmaster
#
class traf::puppetmaster (
  $sysadmins = [],
) {
  class { 'traf::server':
    iptables_public_tcp_ports => [4505, 4506, 8140],
    ssh_hitcount              => '4',
    sysadmins                 => $sysadmins,
  }

  cron { 'updatepuppetmaster':
    user        => 'root',
    minute      => '*/15',
    command     => 'sleep $((RANDOM\%600)) && cd /opt/config/production && git fetch -q && git reset -q --hard @{u} && cronic ./install_modules.sh && touch manifests/site.pp',
    environment => 'PATH=/var/lib/gems/1.8/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin',
    require     => File['/usr/local/bin/cronic'],
  }

  cron { 'deleteoldreports':
    user        => 'root',
    hour        => '6',
    minute      => '0',
    command     => 'sleep $((RANDOM\%600)) && find /var/lib/puppet/reports -name \'*.yaml\' -mtime +7 -execdir rm {} \;',
    environment => 'PATH=/var/lib/gems/1.8/bin:/usr/bin:/bin:/usr/sbin:/sbin',
  }

  cron { 'backuphiera':
    user        => 'root',
    hour        => '7',
    minute      => '0',
    command     => 'sleep $((RANDOM\%600)) && cronic backupToObjectStorage.sh upload /etc/puppet/hieradata/production/common.yaml',
    environment => 'PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin',
    require     => [ File['/usr/local/bin/cronic'], File['/usr/local/bin/backupToObjectStorage.sh'] ],
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

}
