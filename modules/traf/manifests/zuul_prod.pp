# == Class: traf::zuul_prod
#
class traf::zuul_prod(
  $vhost_name = $::fqdn,
  $port = 80,
  $ssl_port = 443,
  $gerrit_server = '',
  $gerrit_user = '',
  $zuul_ssh_private_key = '',
  $zuul_url = '',
  $url_pattern = '',
  $sysadmins = [],
  $statsd_host = '',
  $gearman_workers = []
) {
  # Turn a list of hostnames into a list of iptables rules
  $iptables_rules = regsubst ($gearman_workers, '^(.*)$', '-m state --state NEW -m tcp -p tcp --dport 4730 -s \1 -j ACCEPT')

  class { 'traf::server':
    iptables_public_tcp_ports => [80],
    iptables_rules6           => $iptables_rules,
    iptables_rules4           => $iptables_rules,
    sysadmins                 => $sysadmins,
  }

  class { '::zuul':
    vhost_name           => $vhost_name,
    gerrit_server        => $gerrit_server,
    gerrit_user          => $gerrit_user,
    zuul_ssh_private_key => $zuul_ssh_private_key,
    zuul_url             => $zuul_url,
    url_pattern          => $url_pattern,
    push_change_refs     => false,
    job_name_in_report   => true,
    status_url           => 'http://static.trafodion.org/status/zuul',
    statsd_host          => $statsd_host,
  }

  # Add Zuul public key
  file { '/var/lib/zuul/ssh/id_rsa.pub':
    owner   => 'zuul',
    group   => 'zuul',
    mode    => '0644',
    content => hiera('zuul_ssh_public_key_contents'),
    require => Class['::zuul'],
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

  class { '::recheckwatch':
    gerrit_server                => $gerrit_server,
    gerrit_user                  => $gerrit_user,
    recheckwatch_ssh_private_key => $zuul_ssh_private_key,
  }

  file { '/var/lib/recheckwatch/scoreboard.html':
    ensure  => present,
    source  => 'puppet:///modules/traf/zuul/scoreboard.html',
    require => File['/var/lib/recheckwatch'],
  }

  file { '/var/www/recheckwatch/rechecks.html':
    ensure  => present,
    source  => 'puppet:///modules/traf/zuul/rechecks.html',
    require => File['/var/www/recheckwatch'],
  }

  file { '/home/zuul/.ssh':
    ensure  => directory,
    mode    => '700',
    owner   => 'zuul',
    group   => 'zuul',
    require => User['zuul'],
  }

  file { '/home/zuul/.ssh/config':
    ensure  => present,
    owner   => zuul,
    group   => zuul,
    source  => 'puppet:///modules/traf/zuul/ssh_config',
    require => User['zuul'],
  }

  file { '/home/zuul/.gitconfig':
    ensure  => present,
    owner   => zuul,
    group   => zuul,
    source  => 'puppet:///modules/traf/zuul/gitconfig',
    require => User['zuul'],
  }

  # Fix default Zuul webpage
  # Need Graphite server and static (main) web server
#  file { '/var/lib/zuul/www/status.html':
#    ensure  => present,
#    source  => 'puppet:///modules/traf/zuul/status.html',
#  }
#
#  file { '/var/lib/zuul/www/status.js':
#    ensure  => present,
#    source  => 'puppet:///modules/traf/zuul/status.js',
#    require => File['/var/lib/zuul/www/status.html'],
#  }
#
#  exec { 'Remove_initial_index_relink_to_status':
#    cwd     => "/var/lib/zuul/www",
#    path    => "/usr/bin:/usr/sbin:/bin",
#    command => 'rm index.html; ln -s status.html index.html',
#    require => File['/var/lib/zuul/www/index.html'],
#  }
}
