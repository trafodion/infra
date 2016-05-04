# == Class: traf::dev
#
class traf::dev (
  $bare = false,
  $certname = $::fqdn,
  $sysadmins = [],
  $python3 = false,
  $include_pypy = false,
  $jenkins_ssh_key = '',
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

  host { "${::hostname}.esgyn.com":
    ensure       => present,
    host_aliases => $::hostname,
    ip           => $::ipaddress,
  }

  class { 'traf::server':
    iptables_public_tcp_ports => ['5900:5999','45000:46000'], # VNC, DCS
    certname                  => $certname,
    sysadmins                 => $sysadmins,
  }
  class { 'jenkins::slave':
    bare         => $bare,
    ssh_key      => $jenkins_ssh_key,
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

  file { '/etc/yum.repos.d/scootersoftware.repo':
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    source => 'puppet:///modules/traf/dev/scootersoftware.repo',
  }
  file { '/etc/BC4Key.txt':
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => hiera('BC4Key'),
  }
  package { 'bcompare':
    ensure  => present,
    require => File['/etc/BC4Key.txt','/etc/yum.repos.d/scootersoftware.repo'],
  }


  package { ['emacs','gitk','gedit','kdesdk','firefox','vim-enhanced','xterm','gnuplot','valgrind','apr-util-devel' ]:
    ensure => present,
  }
  # work-around for group install
  if $::operatingsystemmajrelease == '7' {
    exec { 'Desktop':
      timeout => 1200,
      unless  => '/usr/bin/yum grouplist "Server with GUI" | /bin/grep "^Installed Environment Groups"',
      command => '/usr/bin/yum -y groupinstall "Server with GUI"',
    }
  } elsif $::operatingsystemmajrelease == '6' {
    exec { 'Desktop':
      timeout => 1200,
      unless  => '/usr/bin/yum grouplist "Desktop" | /bin/grep "^Installed Groups"',
      command => '/usr/bin/yum -y groupinstall "Desktop"',
    }
    exec { 'GenDesktop':
      timeout => 1200,
      unless  => '/usr/bin/yum grouplist "General Purpose Desktop" | /bin/grep "^Installed Groups"',
      command => '/usr/bin/yum -y groupinstall "General Purpose Desktop"',
    }
    exec { 'XWin':
      timeout => 1200,
      unless  => '/usr/bin/yum grouplist "X Window System" | /bin/grep "^Installed Groups"',
      command => '/usr/bin/yum -y groupinstall "X Window System"',
    }
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

  # Real VNC does not work with Centos7 Gnome
  if $::operatingsystemmajrelease == '6' {
    exec { 'get_vnc_rpm' :
      command => "/usr/bin/scp downloads.esgyn.local:/srv/static/downloads/dev-tools/VNC-Server-5.2.3-Linux-x64.rpm /opt/dev",
      timeout => 900,
      user    => 'jenkins',
      creates => "/opt/dev/VNC-Server-5.2.3-Linux-x64.rpm",
      require => File['/opt/dev'],
    }
    exec { 'rm_tiger' :
      onlyif  => '/usr/bin/yum list "tiger*" "abrt*" | /bin/grep "^Installed Packages"',
      command => '/usr/bin/yum -y erase "tiger*" "abrt*"',
      require => Exec['Desktop'],
    }
    package { 'realvnc-vnc-server':
      ensure   => present,
      provider => rpm,
      source   => "/opt/dev/VNC-Server-5.2.3-Linux-x64.rpm",
      require  => [ Exec['get_vnc_rpm'], Package['xterm'], Exec['rm_tiger'] ],
    }
    file { '/etc/vnc/config.d/Xvnc':
      ensure  => present,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      content => "UserPasswdVerifier=VncAuth",
      require => Package['realvnc-vnc-server'],
    }
    $vnc_key = hiera('VNC_key')
    exec { 'vnc_license' :
      command => "/usr/bin/vnclicense -add $vnc_key",
      unless  => '/usr/bin/vnclicense -check',
      require => Package['realvnc-vnc-server'],
    }
  }
  if $::operatingsystemmajrelease == '7' {
    package { 'tigervnc-server':
      ensure  => present,
    }
  }
  # Atom - editor for asciidoc, etc
  exec { 'get_atom_rpm' :
    command => "/usr/bin/wget https://github.com/atom/atom/releases/download/v1.7.2/atom.x86_64.rpm",
    cwd     => "/opt/dev",
    timeout => 900,
    creates => "/opt/dev/atom.x86_64.rpm",
    require => File['/opt/dev'],
  }
  package { 'atom':
    ensure   => present,
    provider => rpm,
    source   => "/opt/dev/atom.x86_64.rpm",
    require  => Exec['get_atom_rpm'],
  }


  file { '/opt/dev':
    ensure => directory,
    owner  => 'jenkins',
    group  => 'jenkins',
    mode   => '0644',
  }
  # eclipse
  exec { 'get_dev_eclipse' :
    command => "/usr/bin/scp traf-builds.esgyn.com:/srv/static/downloads/dev-tools/eclipse-java-cpp-mars-R-linux-gtk-x86_64.tgz /opt/dev",
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
    command => "/usr/bin/scp traf-builds.esgyn.com:/srv/static/downloads/dev-tools/local_sw_dist.tgz /opt/dev",
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
    groups  => ['sudo'],
    require => Group['sudo'],
  }
}

