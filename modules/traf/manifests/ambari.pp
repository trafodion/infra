# == Class: traf::ambari
#
# Single-Node set-up, only useful for simple functional testing
# Installs & runs ambari server
class traf::ambari (
  $distro      = '',
) {



  if $distro == 'AHW2.1' {
    $repoamb = 'puppet:///modules/traf/hadoop/ambari-1.6.1.repo'
  }
  if $distro == 'AHW2.2' {
    $repoamb = 'puppet:///modules/traf/hadoop/ambari-1.7.0.repo'
  }

  file { '/etc/yum.repos.d/ambari.repo':
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    source => $repoamb,
  }

  package { ['ambari-server','ambari-agent']:
    ensure  => present,
    require => File['/etc/yum.repos.d/ambari.repo'],
  }

  exec { 'ambari-setup':
    command => '/usr/sbin/ambari-server setup --java /usr/lib/jvm/java-1.7.0 --silent',
    creates => '/etc/ambari-server/conf/password.dat',
    require => Package['ambari-server'],
  }

  service { 'ambari-server':
    ensure  => running,
    status  => '/usr/sbin/ambari-server status | /bin/grep -q "Server running"',
    require => Exec['ambari-setup'],
  }

  service { 'ambari-agent':
    ensure  => running,
    status  => '/usr/sbin/ambari-agent status | /bin/grep -q "agent running"',
    require => Service['ambari-server'],
  }
}

