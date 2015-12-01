# == Class: traf::testm
#
class traf::testm (
  $bare = false,
  $certname = $::fqdn,
  $sysadmins = [],
  $python3 = false,
  $include_pypy = false,
) {
  include traf
  include traf::buildtest
  include traf::cloudwest
  #include traf::tmpcleanup
  #include traf::automatic_upgrades

  #include traf::python276

  class { 'traf::server':
    iptables_public_tcp_ports => ['5900:5999'], # VNC
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



  package { ['tigervnc-server','emacs','gitk']:
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


  # firefox
  file { '/opt/dev':
    ensure => directory,
    owner  => 'jenkins',
    group  => 'jenkins',
    mode   => '0644',
  }

  # user accounts
  $useradmins = hiera('test_admins')
  traf::devuser {$useradmins : 
    groups => ['sudo'],
  }
}

