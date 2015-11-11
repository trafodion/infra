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
    iptables_public_tcp_ports => ['5900:5999','45000:46000'], # VNC, DCS
    certname                  => $certname,
    sysadmins                 => $sysadmins,
  }
  class { 'jenkins::slave':
    bare         => $bare,
    ssh_key      => $traf::jenkins_ssh_key,
    sudo         => false,
    python3      => $python3,
    include_pypy => $include_pypy,
  }
  # add jenkins public and private ssh keys
  file { '/home/jenkins/.ssh/id_rsa':
    ensure  => present,
    owner   => 'jenkins',
    group   => 'jenkins',
    mode    => '0600',
    content => hiera('jenkins_ssh_private_key_contents'),
  }

  file { '/home/jenkins/.ssh/id_rsa.pub':
    ensure  => present,
    owner   => 'jenkins',
    group   => 'jenkins',
    mode    => '0644',
    content => $traf::jenkins_ssh_pub_key,
  }



  package { ['emacs','gitk','gedit']:
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

  # hub
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

  # trafodion limits
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


  # firefox
  file { '/opt/dev':
    ensure => directory,
    owner  => 'jenkins',
    group  => 'jenkins',
    mode   => '0644',
  }
  exec { 'get_dev_tools' :
    command => "/usr/bin/scp traf-downloads.esgyn.com:/srv/static/downloads/dev-tools/firefox-38.0.5.tar.bz2 /opt/dev",
    timeout => 900,
    user    => 'jenkins',
    creates => "/opt/dev/firefox-38.0.5.tar.bz2",
    require => File['/opt/dev'],
  }
  exec { 'untar-firefox' :
    command => '/bin/tar xf /opt/dev/firefox-38.0.5.tar.bz2',
    cwd     => "/opt", 
    creates => "/opt/firefox",
    require => Exec['get_dev_tools'],
  }
  # eclipse
  exec { 'get_dev_eclipse' :
    command => "/usr/bin/scp traf-downloads.esgyn.com:/srv/static/downloads/dev-tools/eclipse-java-cpp-mars-R-linux-gtk-x86_64.tgz /opt/dev",
    timeout => 900,
    user    => 'jenkins',
    creates => "/opt/dev/eclipse-java-cpp-mars-R-linux-gtk-x86_64.tgz",
    require => File['/opt/dev'],
  }
  exec { 'untar-eclipse' :
    command => '/bin/tar xf /opt/dev/eclipse-java-cpp-mars-R-linux-gtk-x86_64.tgz',
    cwd     => "/opt", 
    creates => "/opt/eclipse",
    require => Exec['get_dev_eclipse'],
  }
  # local SW
  exec { 'get_dev_swdist' :
    command => "/usr/bin/scp traf-downloads.esgyn.com:/srv/static/downloads/dev-tools/local_sw_dist.tgz /opt/dev",
    timeout => 900,
    user    => 'jenkins',
    creates => "/opt/dev/local_sw_dist.tgz",
    require => File['/opt/dev'],
  }
  exec { 'untar-swdist' :
    command => '/bin/tar xf /opt/dev/local_sw_dist.tgz',
    cwd     => "/opt", 
    creates => "/opt/local_sw_dist",
    require => Exec['get_dev_swdist'],
  }

  # user accounts
  $userlist = hiera('user_accts')
  traf::devuser {$userlist :
    groups => [],
  }
  $useradmins = hiera('user_admins')
  traf::devuser {$useradmins : 
    groups => ['sudo'],
  }
}

