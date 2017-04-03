# Class: iptables
#
# http://projects.puppetlabs.com/projects/1/wiki/Module_Iptables_Patterns
#
# params:
#   rules4: A list of additional iptables v4 rules
#          eg: [ '-m udp -p udp -s 127.0.0.1 --dport 8125 -j ACCEPT' ]
#   rules6: A list of additional iptables v6 rules
#          eg: [ '-m udp -p udp -s ::1 --dport 8125 -j ACCEPT' ]
#   public_tcp_ports: List of integer TCP ports on which to allow all traffic
#   public_udp_ports: List of integer UDP ports on which to allow all traffic
class iptables(
  $rules4 = [],
  $rules6 = [],
  $public_tcp_ports = [],
  $public_udp_ports = [],
  $blacklist_rules4 = [],
  $blacklist_rules6 = [],
  $rate_unlimit_ips4 = [],
  $rate_unlimit_ips6 = [],
  $ssh_hitcount = '3',
  $log_file = '/var/log/iptables.log',
) {

  include iptables::params

  package { 'iptables':
    ensure => present,
    name   => $::iptables::params::package_name,
  }

  service { 'iptables':
    name       => $::iptables::params::service_name,
    require    => Package['iptables'],
    hasstatus  => $::iptables::params::service_has_status,
    status     => $::iptables::params::service_status_cmd,
    hasrestart => $::iptables::params::service_has_restart,
  }
  if $::operatingsystemmajrelease == '7' {
    service { 'firewalld':
      ensure => stopped,
    }
  }

  file { $::iptables::params::rules_dir:
    ensure  => directory,
    require => Package['iptables'],
  }

  # This file is not required on Red Hat distros... but it
  # won't hurt to softlink to it either
  file { "${::iptables::params::rules_dir}/rules":
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content => template('iptables/rules.erb'),
    require => [
      Package['iptables'],
      File[$::iptables::params::rules_dir],
    ],
    # When this file is updated, make sure the rules get reloaded.
    notify  => Service['iptables'],
  }

  file { $::iptables::params::ipv4_rules:
    ensure  => link,
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    target  => "${::iptables::params::rules_dir}/rules",
    require => File["${::iptables::params::rules_dir}/rules"],
    notify  => Service['iptables'],
  }

  file { $::iptables::params::ipv6_rules:
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0640',
    content => template('iptables/rules.v6.erb'),
    require => [
      Package['iptables'],
      File[$::iptables::params::rules_dir],
    ],
    # When this file is updated, make sure the rules get reloaded.
    notify  => Service['iptables'],
    replace => true,
  }

  file { '/etc/rsyslog.d/iptables.conf':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    content => template('iptables/iptables.conf.erb'),
    notify  => Service['rsyslog'],
  }

  include logrotate
  logrotate::file { 'iptables.log':
    log     => $log_file,
    options => [
      'compress',
      'copytruncate',
      'missingok',
      'rotate 30',
      'daily',
      'notifempty',
    ],
    require => [ Service['iptables'], File['/etc/rsyslog.d/iptables.conf'] ],
  }

  file { '/etc/modprobe.d/xt_recent.conf':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    content => 'options xt_recent ip_list_tot=500 ip_pkt_list_tot=150',
    notify  => Exec['reload xt_recent'],
  }

  exec { 'reload xt_recent':
    command     => '/sbin/modprobe -r xt_recent; /sbin/modprobe xt_recent',
    refreshonly => true,
    notify      => Service['iptables'],
  }
}
