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

  package { ['tigervnc-server','emacs']:
    ensure => present,
  }
  # work-around for group install
  exec { 'Desktop':
    unless  => '/usr/bin/yum grouplist "Desktop" | /bin/grep "^Installed Groups"',
    command => '/usr/bin/yum -y groupinstall "Desktop"',
  }
  exec { 'GenDesktop':
    unless  => '/usr/bin/yum grouplist "General Purpose Desktop" | /bin/grep "^Installed Groups"',
    command => '/usr/bin/yum -y groupinstall "General Purpose Desktop"',
  }
  exec { 'XWin':
    unless  => '/usr/bin/yum grouplist "X Window System" | /bin/grep "^Installed Groups"',
    command => '/usr/bin/yum -y groupinstall "X Window System"',
  }

  $hubver = "2.2.1"
  $hub_full = "hub-linux-amd64-$hubver"
  $hub_src = "https://github.com/github/hub/releases/download/v$hubver/$hub_full.tar.gz"

  exec { 'get_hub':
    command => "/usr/bin/wget $hub_src",
    cwd     => "/opt",
    creates => "/opt/$hub_full.tar.gz",
  }
  exec { 'untar_hub':
    command => "/bin/tar -xf /opt/$hub_full.tar.gz",
    cwd     => "/opt",
    creates => "/opt/$hub_full/hub",
    require => Exec['get_hub'],
  }
  file { '/usr/local/bin/hub':
    ensure  => link,
    target  => "/opt/$hub_full/hub",
    require => Exec['untar_hub'],
  }

  file { '/etc/security/limits.d/trafdev.conf':
    ensure => present,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    source => "puppet:///modules/traf/trafdev-limits.conf",
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
