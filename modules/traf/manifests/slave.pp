# == Class: traf::slave
#
class traf::slave (
  $bare = false,
  $certname = $::fqdn,
  $ssh_key = '',
  $sysadmins = [],
  $python3 = false,
  $include_pypy = false,
  $hive_sql_pw = '',
  $distro = '',
  $logs_host = '',
) {
  include traf
  include traf::buildtest
  include traf::tmpcleanup
  include traf::automatic_upgrades

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
  # set up mount point for jenkins workspaces
  # prevent seltype from changing to mnt_t after jenkinsuser.pp sets to user_home_t
  file { '/mnt/jenkins':
    ensure                  => directory,
    owner                   => 'jenkins',
    group                   => 'jenkins',
    mode                    => '0755',
    selinux_ignore_defaults => true,
  }
  mount { '/home/jenkins':
    ensure  => mounted,
    atboot  => true,
    fstype  => 'none',
    options => 'bind',
    device  => '/mnt/jenkins',
    require => [ Class['jenkins::slave'], File['/mnt/jenkins'] ],
  }

  # swap file
  # take the defaults - same size as memory
  class { 'swap_file':
    swapfile => '/mnt/swapfile',
  }


  # install rake and puppetlabs_spec_helper from ruby gems
  # so puppet-lint can run on the slaves
  package { 'rake':
    ensure   => latest,
    provider => 'gem',
  }

  package { 'puppetlabs_spec_helper':
    ensure   => latest,
    provider => 'gem',
    require  => Package['rspec'], # work-around
  }
  # work-around, until fix merged: https://github.com/puppetlabs/puppetlabs_spec_helper/pull/90
  package { 'rspec':
    ensure   => '2.99.0',
    provider => 'gem',
  }

  # add known host keys for static server to upload logs, etc
  sshkey { 'logs.trafodion.org':
    ensure       => present,
    host_aliases => [
      'downloads.trafodion.org',
      'static.trafodion.org',
      'mvnrepo.trafodion.org',
    ],
    type         => 'ssh-rsa',
    key          => $logs_host,
  }

  # add jenkins public and private ssh keys
  file { '/home/jenkins/.ssh/id_rsa':
    ensure  => present,
    owner   => 'jenkins',
    group   => 'jenkins',
    mode    => '0600',
    content => hiera('jenkins_ssh_private_key_contents'),
    require => Mount['/home/jenkins'],
  }

  file { '/home/jenkins/.ssh/id_rsa.pub':
    ensure  => present,
    owner   => 'jenkins',
    group   => 'jenkins',
    mode    => '0644',
    content => $traf::jenkins_ssh_pub_key,
    require => Mount['/home/jenkins'],
  }
  # maven scp is too dumb to look at system known_hosts file
  file { '/home/jenkins/.ssh/known_hosts':
    ensure  => present,
    owner   => 'jenkins',
    group   => 'jenkins',
    mode    => '0644',
    source  => '/etc/ssh/ssh_known_hosts',
    require => [ Sshkey['logs.trafodion.org'], Mount['/home/jenkins'] ],
  }


  include jenkins::cgroups

  # manual install distros - no Ambari, no Cloudera Manager
  if $distro =~ /^(CDH)/ {
  # installer will replace this script
  file { '/etc/sudoers.d/jenkins-sudo-hbase':
    ensure => present,
    source => 'puppet:///modules/traf/jenkins/jenkins-sudo-hbase.sudo',
    owner  => 'root',
    group  => 'root',
    mode   => '0440',
  }

  # installer will take care of this
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
  } # CDH* distro

  if $distro == 'CDH4.4' {
    class { 'traf::tpcds':
      require => Class['traf::cdh'],
    }

    class { 'traf::cdh':
      hive_sql_pw => $hive_sql_pw,
      distro      => $distro,
    }
  }
  if $distro == 'CDH5.1' {
    class { 'traf::tpcds':
      require => Class['traf::cdh'],
    }

    class { 'traf::cdh':
      hive_sql_pw => $hive_sql_pw,
      distro      => $distro,
    }
  }
  # Cloudera Manager or Ambari
  if $distro =~ /^CM|^AHW/ {
    # both requires selinux disabled
    class { 'selinux':
      mode => 'disabled',
    }

    # sudo privileged user that can run installer
    # must also be able to ssh to local host
    user::virtual::localuser { 'tinstall':
      realname => 'Trafodion Installer',
      sshkeys  => 'generate',
      groups   => 'sudo',
    }
    file { '/etc/sudoers.d/jenkins-sudo-inst':
      ensure => present,
      source => 'puppet:///modules/traf/jenkins/jenkins-sudo-inst.sudo',
      owner  => 'root',
      group  => 'root',
      mode   => '0440',
    }
    file { '/etc/sudoers.d/jenkins-sudo-regress':
      ensure => present,
      source => 'puppet:///modules/traf/jenkins/jenkins-sudo-regress.sudo',
      owner  => 'root',
      group  => 'root',
      mode   => '0440',
    }

    # json parser for API
    package { 'jq':
      ensure => present,
    }

    class { 'traf::tpcds':
      require => Exec['cluster_setup'],
    }
  }
  # Cloudera Manager distros
  if $distro =~ /^CM/ {
    # cluster set-up script
    file { '/usr/local/bin/cmgr.sh':
      ensure  => present,
      source  => 'puppet:///modules/traf/hadoop/cmgr.sh',
      owner   => 'root',
      group   => 'root',
      mode    => '0754',
      require => Package['jq'],
    }

    # cloudera module sets up yum repo, but does not install this package
    package { 'hadoop-libhdfs':
      ensure  => present,
      require => Class['::cloudera'],
    }
  }

  # Ambari managed distros
  if $distro =~ /^AHW/ {
    # cluster set-up script
    file { '/usr/local/bin/amcluster.sh':
      ensure  => present,
      source  => 'puppet:///modules/traf/hadoop/amcluster.sh',
      owner   => 'root',
      group   => 'root',
      mode    => '0754',
      require => Package['jq'],
    }

    class { 'traf::ambari' :
      distro => $distro,
    }
  }
  if $distro == 'AHW2.1' {
    exec {'cluster_setup':
      command => '/usr/local/bin/amcluster.sh HDP-2.1',
      timeout => 0,
      unless  => '/usr/local/bin/amcluster.sh check HDP-2.1',
      require => [ Class['traf::ambari'], File['/usr/local/bin/amcluster.sh'], ]
    }
  }

  if $distro == 'CM5.1' {
    # For CDH5, header files are in separate package
    package { 'hadoop-libhdfs-devel':
      ensure  => present,
      require => Class['::cloudera'],
    }
    exec {'cluster_setup':
      command => '/usr/local/bin/cmgr.sh 5.1.4',
      timeout => 0,
      unless  => '/usr/local/bin/cmgr.sh check 5.1.4',
      require => [ Class['traf::hive_metastore'], File['/usr/local/bin/cmgr.sh'], ]
    }

    class {'traf::hive_metastore':
      hive_sql_pw     => 'insecure_hive',
      hive_schema_ver => '0.12.0',
      require         => Class['::cloudera'],
    }

    class { '::cloudera':
      cm_server_host   => 'localhost',
      install_cmserver => true,
      use_parcels      => false,
      cdh_version      => '5.1.4',
    }
  }

}
