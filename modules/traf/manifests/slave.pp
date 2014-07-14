# == Class: traf::slave
#
class traf::slave (
  $bare = false,
  $certname = $::fqdn,
  $ssh_key = '',
  $sysadmins = [],
  $python3 = false,
  $include_pypy = false,
) {
  include traf
  include traf::buildtest
  include traf::tmpcleanup
  class { 'traf::automatic_upgrades':
    origins => ['LP-PPA-saltstack-salt precise'],
  }

  include traf::python276

  class { 'traf::server':
    iptables_public_tcp_ports => [40010],
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
  file { '/etc/sudoers.d/jenkins-sudo-hbase':
    ensure => present,
    source => 'puppet:///modules/traf/jenkins/jenkins-sudo-hbase.sudo',
    owner  => 'root',
    group  => 'root',
    mode   => '0440',
  }

  # add jenkins public and private ssh keys
  file { '/home/jenkins/.ssh/id_rsa':
    ensure  => present,
    owner   => 'jenkins',
    group   => 'jenkins',
    mode    => '0600',
    content => hiera('jenkins_ssh_private_key_contents'),
    require => Class['jenkins::slave'],
  }

  file { '/home/jenkins/.ssh/id_rsa.pub':
    ensure  => present,
    owner   => 'jenkins',
    group   => 'jenkins',
    mode    => '0644',
    content => $traf::jenkins_ssh_pub_key,
    require => Class['jenkins::slave'],
  }

  # Admin access for test slaves
  $jenkins_auth_users = {
    creynaga   =>  { pub_key => "$traf::users::creynaga_sshkey"},
  }
  create_resources(jenkins::add_pub_key, $jenkins_auth_users)


  class { 'salt':
    salt_master => 'puppet.trafodion.org',
  }
  include jenkins::cgroups
  include ulimit
  ulimit::conf { 'soft limit_jenkins_procs':
    limit_domain => 'jenkins',
    limit_type   => 'soft',
    limit_item   => 'nproc',
    limit_value  => '267263'
  }
  ulimit::conf { 'hard limit_jenkins_procs':
    limit_domain => 'jenkins',
    limit_type   => 'hard',
    limit_item   => 'nproc',
    limit_value  => '267263'
  }
  ulimit::conf { 'soft limit_jenkins_sigs':
    limit_domain => 'jenkins',
    limit_type   => 'soft',
    limit_item   => 'sigpending',
    limit_value  => '515196'
  }
  ulimit::conf { 'hard limit_jenkins_sigs':
    limit_domain => 'jenkins',
    limit_type   => 'hard',
    limit_item   => 'sigpending',
    limit_value  => '515196'
  }
  ulimit::conf { 'soft limit_jenkins_files':
    limit_domain => 'jenkins',
    limit_type   => 'soft',
    limit_item   => 'nofile',
    limit_value  => '32768'
  }
  ulimit::conf { 'hard limit_jenkins_files':
    limit_domain => 'jenkins',
    limit_type   => 'hard',
    limit_item   => 'nofile',
    limit_value  => '32768'
  }
  # 8GB
  ulimit::conf { 'soft limit_jenkins_mem':
    limit_domain => 'jenkins',
    limit_type   => 'soft',
    limit_item   => 'memlock',
    limit_value  => '8165112'
  }
  # 16 GB
  ulimit::conf { 'hard limit_jenkins_mem':
    limit_domain => 'jenkins',
    limit_type   => 'hard',
    limit_item   => 'memlock',
    limit_value  => '16330224'
  }
}