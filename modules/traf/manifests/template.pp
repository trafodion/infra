# == Class: traf::template
#
# A template host with no running services
#
class traf::template (
  $iptables_public_tcp_ports = [],
  $iptables_public_udp_ports = [],
  $iptables_rules4           = [],
  $iptables_rules6           = [],
  $install_users = true,
  $certname = $::fqdn,
  $rate_unlimit_ips4 = [],
  $rate_unlimit_ips6 = [],
  $ssh_hitcount = '',
) {
  # Turn a list of IPs into a list of iptables rules
  $ipv4_blacklist_ips = hiera('ipv4_all_blacklist', '')
  $ipv6_blacklist_ips = hiera('ipv6_all_blacklist', '')
  if $ipv4_blacklist_ips != '' {
    $block_rules4 = regsubst ($ipv4_blacklist_ips, '^(.*)$', '-s \1 -j DROP')
  }
  if $ipv6_blacklist_ips != '' {
    $block_rules6 = regsubst ($ipv6_blacklist_ips, '^(.*)$', '-s \1 -j DROP')
  }

  include ssh
  include snmpd
  include traf::automatic_upgrades

  class { 'iptables':
    public_tcp_ports  => $iptables_public_tcp_ports,
    public_udp_ports  => $iptables_public_udp_ports,
    rules4            => $iptables_rules4,
    rules6            => $iptables_rules6,
    blacklist_rules4  => $block_rules4,
    blacklist_rules6  => $block_rules6,
    rate_unlimit_ips4 => $rate_unlimit_ips4,
    rate_unlimit_ips6 => $rate_unlimit_ips6,
    ssh_hitcount      => $ssh_hitcount,
  }

  class { 'ntp': }

  class { 'traf::base':
    install_users => $install_users,
    certname      => $certname,
  }

  package { 'strace':
    ensure => present,
  }

  package { 'tcpdump':
    ensure => present,
  }
}
