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
  $certname = $::fqdn
) {
  include ssh
  include snmpd
  include traf::automatic_upgrades

  class { 'iptables':
    public_tcp_ports => $iptables_public_tcp_ports,
    public_udp_ports => $iptables_public_udp_ports,
    rules4           => $iptables_rules4,
    rules6           => $iptables_rules6,
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
