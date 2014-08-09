# == Class: traf::zuul_prod
#
class traf::zuul_prod(
  $vhost_name = $::fqdn,
  $port = 80,
  $ssl_port = 443,
  $gearman_server = '127.0.0.1',
  $gerrit_server = '',
  $gerrit_user = '',
  $gerrit_ssh_host_key = '',
  $zuul_ssh_private_key = '',
  $url_pattern = '',
  $zuul_url = '',
  $swift_authurl = '',
  $swift_user = '',
  $swift_key = '',
  $swift_tenant_name = '',
  $swift_region_name = '',
  $swift_default_container = '',
  $swift_default_logserver_prefix = '',
  $sysadmins = [],
  $statsd_host = '',
  $gearman_workers = [],        # Gearman IPv4 workers
  $gearman6_workers = [],       # Gearman IPv6 workers
) {
  # Turn a list of hostnames into a list of iptables rules
  $iptables4_rules = regsubst ($gearman_workers, '^(.*)$', '-m state --state NEW -m tcp -p tcp --dport 4730 -s \1 -j ACCEPT')
  $iptables6_rules = regsubst ($gearman6_workers, '^(.*)$', '-m state --state NEW -m tcp -p tcp --dport 4730 -s \1 -j ACCEPT')

  class { 'traf::server':
    iptables_public_tcp_ports => [80],
    iptables_rules6           => $iptables6_rules,
    iptables_rules4           => $iptables4_rules,
    sysadmins                 => $sysadmins,
  }

  class { '::zuul':
    vhost_name                     => $vhost_name,
    gearman_server                 => $gearman_server,
    gerrit_server                  => $gerrit_server,
    gerrit_user                    => $gerrit_user,
    zuul_ssh_private_key           => $zuul_ssh_private_key,
    url_pattern                    => $url_pattern,
    zuul_url                       => $zuul_url,
    job_name_in_report             => true,
    status_url                     => 'http://status.trafodion.org/zuul/',
    statsd_host                    => $statsd_host,
    git_email                      => 'jenkins@trafodion.org',
    git_name                       => 'Trafodion Jenkins',
    swift_authurl                  => $swift_authurl,
    swift_user                     => $swift_user,
    swift_key                      => $swift_key,
    swift_tenant_name              => $swift_tenant_name,
    swift_region_name              => $swift_region_name,
    swift_default_container        => $swift_default_container,
    swift_default_logserver_prefix => $swift_default_logserver_prefix,
  }

  class { '::zuul::server': }
  class { '::zuul::merger': }

  if $gerrit_ssh_host_key != '' {
    file { '/home/zuul/.ssh':
      ensure  => directory,
      owner   => 'zuul',
      group   => 'zuul',
      mode    => '0700',
      require => Class['::zuul'],
    }
    file { '/home/zuul/.ssh/known_hosts':
      ensure  => present,
      owner   => 'zuul',
      group   => 'zuul',
      mode    => '0600',
      content => "[review.trafodion.org]:29418,[15.125.67.184]:29418,[192.168.0.33]:29418 ${gerrit_ssh_host_key}",
      replace => true,
      require => File['/home/zuul/.ssh'],
    }
    file { '/home/zuul/.ssh/config':
      ensure  => present,
      owner   => zuul,
      group   => zuul,
      source  => 'puppet:///modules/traf/zuul/ssh_config',
      require => User['zuul'],
    }
  }

  file { '/home/zuul/.gitconfig':
    ensure  => present,
    owner   => zuul,
    group   => zuul,
    source  => 'puppet:///modules/traf/zuul/gitconfig',
    require => User['zuul'],
  }

  file { '/etc/zuul/layout.yaml':
    ensure => present,
    source => 'puppet:///modules/traf/zuul/layout.yaml',
    notify => Exec['zuul-reload'],
  }

  file { '/etc/zuul/openstack_functions.py':
    ensure => present,
    source => 'puppet:///modules/traf/zuul/openstack_functions.py',
    notify => Exec['zuul-reload'],
  }

  file { '/etc/zuul/logging.conf':
    ensure => present,
    source => 'puppet:///modules/traf/zuul/logging.conf',
    notify => Exec['zuul-reload'],
  }

  file { '/etc/zuul/gearman-logging.conf':
    ensure => present,
    source => 'puppet:///modules/traf/zuul/gearman-logging.conf',
    notify => Exec['zuul-reload'],
  }

  file { '/etc/zuul/merger-logging.conf':
    ensure => present,
    source => 'puppet:///modules/openstack_project/zuul/merger-logging.conf',
  }

  class { '::recheckwatch':
    gerrit_server                => $gerrit_server,
    gerrit_user                  => 'recheckwatch',
    recheckwatch_ssh_private_key => $zuul_ssh_private_key,
  }

  file { '/var/lib/recheckwatch/scoreboard.html':
    ensure  => present,
    owner   => recheckwatch,
    group   => recheckwatch,
    source  => 'puppet:///modules/traf/zuul/scoreboard.html',
    require => File['/var/lib/recheckwatch'],
  }

  file { '/var/www/recheckwatch/rechecks.html':
    ensure  => present,
    owner   => recheckwatch,
    group   => recheckwatch,
    source  => 'puppet:///modules/traf/zuul/rechecks.html',
    require => File['/var/www/recheckwatch'],
  }

  file { '/var/lib/recheckwatch/ssh/id_rsa.pub':
    owner   => 'recheckwatch',
    group   => 'recheckwatch',
    mode    => '0644',
    content => hiera('zuul_ssh_public_key_contents'),
    require => File['/var/lib/recheckwatch'],
  }

  file { '/home/recheckwatch/.ssh':
    ensure  => directory,
    mode    => '700',
    owner   => 'recheckwatch',
    group   => 'recheckwatch',
    require => User['recheckwatch'],
  }

  file { '/home/recheckwatch/.ssh/config':
    ensure  => present,
    owner   => recheckwatch,
    group   => recheckwatch,
    source  => 'puppet:///modules/traf/recheckwatch/ssh_config',
    require => User['recheckwatch'],
  }

  file { '/home/recheckwatch/.gitconfig':
    ensure  => present,
    owner   => recheckwatch,
    group   => recheckwatch,
    source  => 'puppet:///modules/traf/recheckwatch/gitconfig',
    require => User['recheckwatch'],
  }
}
