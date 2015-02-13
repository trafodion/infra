# == Class: traf::ldap
#
# Installs LDAP Server
#
class traf::ldap (
  $sysadmins = [],
) {
  class { 'traf::server':
    iptables_public_tcp_ports => [22, 389, 636],
    sysadmins                 => $sysadmins,
  }

  if ($::osfamily == 'Debian') {
    package { ['slapd','ldap-utils']:
      ensure => present,
    }
  }
  elsif $::osfamily == 'RedHat' {
    package { ['openldap', 'openldap-clients']:
      ensure => present,
    }
  }
}
