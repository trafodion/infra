# == Class: traf::dev
#
class traf::dev (
  $bare = false,
  $certname = $::fqdn,
  $sysadmins = [],
  $python3 = false,
  $include_pypy = false,
) {
  include traf
  include traf::buildtest
  include traf::tmpcleanup
  include traf::automatic_upgrades

  include traf::python276

  # default location for TOOLSDIR
  file { '/opt/home' :
    ensure => link,
    target => '/opt/traf',
  }

  class { 'traf::server':
    iptables_public_tcp_ports => ['5900:5999'], # VNC
    certname                  => $certname,
    sysadmins                 => $sysadmins,
  }

  package { 'tigervnc-server':
    ensure => present,
  }

  # swap file
  # take the defaults - same size as memory
  class { 'swap_file':
    swapfile => '/mnt/swapfile',
  }


  # /etc/hosts entries

  # local subnet for US East slaves
  host { 'puppet3.trafodion.org':
    ensure       => present,
    host_aliases => 'puppet3',
    ip           => '172.16.0.46',
  }

  # external IP, dashboard in US West
  host { 'dashboard.trafodion.org':
    ensure       => present,
    host_aliases => 'dashboard',
    ip           => '15.125.67.175',
  }


}
