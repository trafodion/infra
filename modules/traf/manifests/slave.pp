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
  }
  class { 'jenkins::slave':
    bare         => $bare,
    ssh_key      => $traf::jenkins_ssh_key,
    sudo         => false,
    python3      => $python3,
    include_pypy => $include_pypy,
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
  sshkey { 'traf-testlogs.esgyn.com':
    ensure       => present,
    host_aliases => [
      'traf-builds.esgyn.com',
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
  # keep Gerrit server's SSL certificates up to date
  file { '/etc/pki/ca-trust/source/anchors/intermediate.crt':
    ensure  => present,
    content => hiera('jenkins02_ssl_chain_file_contents'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    notify  => Exec['update-ca-trust'],
  }

  file { '/etc/pki/ca-trust/source/anchors/review.crt':
    ensure  => present,
    content => hiera('gerrit_ssl_cert_file_contents'),
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

  if $distro =~ /^AHW|^CM/ {
    class { 'traf::hadoop':
      certname    => $certname,
      distro      => $distro,
      hive_sql_pw => $hive_sql_pw,
    }
  }

}
