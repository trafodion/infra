# == Class: jenkins::master
#
class jenkins::master(
  $logo = '',
  $vhost_name = $::fqdn,
  $vhost_alias = '',
  $serveradmin = "webmaster@${::fqdn}",
  $ssl_cert_file = '',
  $ssl_key_file = '',
  $ssl_chain_file = '',
  $ssl_cert_file_contents = '', # If left empty puppet will not create file.
  $ssl_key_file_contents = '', # If left empty puppet will not create file.
  $ssl_chain_file_contents = '', # If left empty puppet will not create file.
  $jenkins_ssh_private_key = '',
  $jenkins_ssh_public_key = '',
) {
  include pip
  include apt

  package { 'openjdk-7-jre-headless':
    ensure => present,
  }

  package { 'openjdk-6-jre-headless':
    ensure  => purged,
    require => Package['openjdk-7-jre-headless'],
  }

  #This key is at http://pkg.jenkins-ci.org/debian/jenkins-ci.org.key
  apt::key { 'jenkins':
    key        => '150FDE3F7787E7D11EF4E12A9B7D32F2D50582E6',
    key_source => 'http://pkg.jenkins-ci.org/debian/jenkins-ci.org.key',
    require    => Package['wget'],
  }

  apt::source { 'jenkins':
    location    => 'http://pkg.jenkins-ci.org/debian-stable',
    release     => 'binary/',
    repos       => '',
    require     => [
      Apt::Key['jenkins'],
      Package['openjdk-7-jre-headless'],
    ],
    include_src => false,
  }

  include apache
  include apache::mod::rewrite
  apache::vhost { "$vhost_name-redirect":
    serveraliases   => $vhost_alias,
    port            => 80,
    docroot         => '/var/www',
    priority        => '20',
    redirect_status => 'permanent',
    redirect_dest   => 'https://$vhost_name/',
  }
  apache::vhost { $vhost_name:
    serveraliases => $vhost_alias,
    port          => 443,
    docroot       => '/var/www',
    priority      => '50',
    ssl           => true,
    serveradmin   => $serveradmin,
    ssl_chain     => $ssl_chain_file,
    ssl_key       => $ssl_key_file,
    ssl_cert      => $ssl_cert_file,
    rewrites      => [
      { rewrite_cond => ["%{HTTP_HOST} !$vhost_name"],
        rewrite_rule => ["^.*$ https://$vhost_name/"],
      },
    ],
  }

  if $ssl_cert_file_contents != '' {
    file { $ssl_cert_file:
      owner   => 'root',
      group   => 'root',
      mode    => '0640',
      content => $ssl_cert_file_contents,
      before  => Apache::Vhost[$vhost_name],
    }
  }

  if $ssl_key_file_contents != '' {
    file { $ssl_key_file:
      owner   => 'root',
      group   => 'ssl-cert',
      mode    => '0640',
      content => $ssl_key_file_contents,
      require => Package['ssl-cert'],
      before  => Apache::Vhost[$vhost_name],
    }
  }

  if $ssl_chain_file_contents != '' {
    file { $ssl_chain_file:
      owner   => 'root',
      group   => 'root',
      mode    => '0640',
      content => $ssl_chain_file_contents,
      before  => Apache::Vhost[$vhost_name],
    }
  }

  $packages = [
    'ssl-cert',
  ]

  package { $packages:
    ensure => present,
  }

  package { 'jenkins':
    ensure  => 'present',
    require => Apt::Source['jenkins'],
  }

  exec { 'update apt cache':
    subscribe   => File['/etc/apt/sources.list.d/jenkins.list'],
    refreshonly => true,
    path        => '/bin:/usr/bin',
    command     => 'apt-get update',
  }

  file { '/var/lib/jenkins':
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'adm',
    require => Package['jenkins'],
  }

  file { '/var/lib/jenkins/.ssh/':
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'nogroup',
    mode    => '0700',
    require => File['/var/lib/jenkins'],
  }

  file { '/var/lib/jenkins/.ssh/id_rsa':
    owner   => 'jenkins',
    group   => 'nogroup',
    mode    => '0600',
    content => $jenkins_ssh_private_key,
    replace => true,
    require => File['/var/lib/jenkins/.ssh/'],
  }

  file { '/var/lib/jenkins/.ssh/id_rsa.pub':
    owner   => 'jenkins',
    group   => 'nogroup',
    mode    => '0644',
    content => $jenkins_ssh_public_key,
    replace => true,
    require => File['/var/lib/jenkins/.ssh/'],
  }

  file { '/var/lib/jenkins/userContent':
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'nogroup',
    mode    => '0755',
    require => File['/var/lib/jenkins'],
  }

  file { '/var/lib/jenkins/userContent/traf.css':
    ensure  => present,
    owner   => 'jenkins',
    group   => 'nogroup',
    source  => 'puppet:///modules/jenkins/traf.css',
    require => File['/var/lib/jenkins/userContent'],
  }

  file { '/var/lib/jenkins/userContent/traf.js':
    ensure  => present,
    owner   => 'jenkins',
    group   => 'nogroup',
    content => template('jenkins/traf.js.erb'),
    require => File['/var/lib/jenkins/userContent'],
  }

  file { '/var/lib/jenkins/userContent/Trafodion-page-bkg.jpg':
    ensure  => present,
    owner   => 'jenkins',
    group   => 'nogroup',
    source  => 'puppet:///modules/traf/Trafodion-page-bkg.jpg',
    require => File['/var/lib/jenkins/userContent'],
  }

  file { '/var/lib/jenkins/logger.conf':
    ensure  => present,
    owner   => 'jenkins',
    group   => 'nogroup',
    source  => 'puppet:///modules/jenkins/logger.conf',
    require => File['/var/lib/jenkins'],
  }

  file { '/var/lib/jenkins/userContent/title.png':
    ensure  => present,
    owner   => 'jenkins',
    group   => 'nogroup',
    source  => "puppet:///modules/traf/${logo}",
    require => File['/var/lib/jenkins/userContent'],
  }

  file { '/usr/local/jenkins':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { '/usr/local/jenkins/slave_scripts':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    recurse => true,
    purge   => true,
    force   => true,
    require => File['/usr/local/jenkins'],
    source  => 'puppet:///modules/jenkins/slave_scripts',
  }
}
