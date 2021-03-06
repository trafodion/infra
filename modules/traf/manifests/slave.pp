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
    iptables_public_tcp_ports => [24400, 40010],
    certname                  => $certname,
    sysadmins                 => $sysadmins,
    rate_unlimit_ips4         => [ '52.35.27.222',        # jenkins public IP
                                   '172.31.0.0/16',       # VPC
                                   "$::ec2_public_ipv4",  # slave's own public IP
                                 ],
  }
  class { 'jenkins::slave':
    bare         => $bare,
    ssh_key      => $traf::jenkins_ssh_key,
    sudo         => false,
    python3      => $python3,
    include_pypy => $include_pypy,
  }


  # add known host keys for static server to upload logs, etc
  sshkey { 'traf-testlogs.esgyn.com':
    ensure       => present,
    host_aliases => [
      'traf-builds.esgyn.com',
    ],
    type         => 'ssh-rsa',
    key          => $logs_host,
  }
  # add known host keys for current host, to allow ssh localhost
  sshkey { "$::hostname":
    ensure       => present,
    host_aliases => [
      "${::hostname}.${::domain}",
      "localhost",
    ],
    type         => 'ssh-rsa',
    key          => $::sshrsakey,
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
  # maven scp is too dumb to look at system known_hosts file
  file { '/home/jenkins/.ssh/known_hosts':
    ensure  => present,
    owner   => 'jenkins',
    group   => 'jenkins',
    mode    => '0644',
    source  => '/etc/ssh/ssh_known_hosts',
    require => [ Sshkey['traf-testlogs.esgyn.com'] ],
  }

  # allow Jenkins to run script to upload files to CDN
  file { '/etc/sudoers.d/jenkins-sudo-cdn':
    ensure => present,
    source => 'puppet:///modules/traf/jenkins/jenkins-sudo-cdn.sudo',
    owner  => 'root',
    group  => 'root',
    mode   => '0440',
  }

  # keep intermediate SSL certificates up to date
  file { '/etc/pki/ca-trust/source/anchors/intermediate.crt':
    ensure  => present,
    content => hiera('jenkins02_ssl_chain_file_contents'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    notify  => Exec['update-ca-trust'],
  }

  exec { 'update-ca-trust':
    cwd         => '/etc/pki/ca-trust/source/anchors',
    command     => '/usr/bin/update-ca-trust enable; /usr/bin/update-ca-trust extract',
    refreshonly => true,
  }

  if $distro =~ /^AHW|^CM|^VH/ {
    class { 'traf::hadoop':
      certname    => $certname,
      distro      => $distro,
      hive_sql_pw => $hive_sql_pw,
    }
  }

}
