# == Class: traf::jenkins
#
class traf::jenkins (
  $vhost_name = $::fqdn,
  $vhost_alias = '',
  $port = 80,
  $ssl_port = 443,
  $jenkins_jobs_password = '',
  $jenkins_jobs_username = 'JJB',
  $manage_jenkins_jobs = true,
  $ssl_cert_file_contents = '',
  $ssl_key_file_contents = '',
  $ssl_chain_file_contents = '',
  $jenkins_ssh_private_key = '',
  $sysadmins = []
) {
  include traf

  class { 'traf::server':
    iptables_public_tcp_ports => [80, 443, 8080],
    sysadmins                 => $sysadmins,
  }

  # json parser for API
  package { 'jq':
    ensure => present,
  }
  # maven for docs build job
  package { 'maven':
    ensure => present,
  }

  if $ssl_chain_file_contents != '' {
    $ssl_chain_file = '/etc/ssl/certs/intermediate.pem'
  } else {
    $ssl_chain_file = ''
  }

  class { '::jenkins::master':
    vhost_name              => $vhost_name,
    vhost_alias             => $vhost_alias,
    serveradmin             => 'trafodion-infrastructure@lists.launchpad.net',
    logo                    => 'Trafodion.png',
    ssl_cert_file           => "/etc/ssl/certs/${vhost_name}.pem",
    ssl_key_file            => "/etc/ssl/private/${vhost_name}.key",
    ssl_chain_file          => $ssl_chain_file,
    ssl_cert_file_contents  => $ssl_cert_file_contents,
    ssl_key_file_contents   => $ssl_key_file_contents,
    ssl_chain_file_contents => $ssl_chain_file_contents,
    jenkins_ssh_private_key => $jenkins_ssh_private_key,
    jenkins_ssh_public_key  => $traf::jenkins_ssh_pub_key,
  }

  $ghauth = hiera('jenkins_github_auth','none')
  if $ghauth != 'none' {
    file { '/var/lib/jenkins/ghtoken':
      ensure  => present,
      content => $ghauth,
      owner   => 'jenkins',
      group   => 'jenkins',
      mode    => '0600',
    }
  }


  # ensure user jenkins home directory is set correctly in /etc/passwd
  group { 'jenkins':
    ensure => present,
  }

  user { 'jenkins':
    ensure     => present,
    comment    => 'Jenkins User',
    home       => '/var/lib/jenkins',
    gid        => 'jenkins',
    shell      => '/bin/sh',
    membership => 'minimum',
    require    => Group['jenkins'],
  }

# Manage plugins manually via admin interface
#  # set up jenkins plugins
#  jenkins::plugin { 'ansicolor':
#    version => '0.4.1',
#  }
#  jenkins::plugin { 'build-timeout':
#    version => '1.14.1',
#  }
#  jenkins::plugin { 'build-flow-plugin':
#    version => '0.17',
#  }
#  jenkins::plugin { 'build-user-vars-plugin':
#    version => '1.4',
#  }
#  jenkins::plugin { 'conditional-buildstep':
#    version => '1.3.3',
#  }
#  jenkins::plugin { 'copyartifact':
#    version => '1.35.1',
#  }
#  jenkins::plugin { 'dashboard-view':
#    version => '2.9.4',
#  }
#  jenkins::plugin { 'envinject':
#    version => '1.90',
#  }
#  jenkins::plugin { 'email-ext':
#    version => '2.40.5',
#  }
#  jenkins::plugin { 'git':
#    version => '2.3.5',
#  }
#  jenkins::plugin { 'github-api':
#    version => '1.67',
#  }
#  jenkins::plugin { 'git-client':
#    version => '1.17.1',
#  }
#  jenkins::plugin { 'github-oauth':
#    version => '0.20',
#  }
#  jenkins::plugin { 'github':
#    version => '1.11.3',
#  }
#  jenkins::plugin { 'ghprb':
#    version => '1.25',
#  }
#  jenkins::plugin { 'greenballs':
#    version => '1.14',
#  }
#  jenkins::plugin { 'htmlpublisher':
#    version => '1.3',
#  }
#  jenkins::plugin { 'extended-read-permission':
#    version => '1.0',
#  }
#  jenkins::plugin { 'postbuild-task':
#    version => '1.8',
#  }
#  jenkins::plugin { 'jobConfigHistory':
#    version => '2.11',
#  }
#  jenkins::plugin { 'mailer':
#    version => '1.15',
#  }
#  jenkins::plugin { 'matrix-auth':
#    version => '1.2',
#  }
#  jenkins::plugin { 'monitoring':
#    version => '1.55.0',
#  }
#  jenkins::plugin { 'jenkins-multijob-plugin':
#    version => '1.16',
#  }
#  jenkins::plugin { 'nodelabelparameter':
#    version => '1.5.1',
#  }
#  jenkins::plugin { 'notification':
#    version => '1.9',
#  }
#  jenkins::plugin { 'parameterized-trigger':
#    version => '2.26',
#  }
#  jenkins::plugin { 'Parameterized-Remote-Trigger':
#    version => '2.1.3',
#  }
#  jenkins::plugin { 'postbuildscript':
#    version => '0.17',
#  }
#  jenkins::plugin { 'publish-over-ftp':
#    version => '1.11',
#  }
#  jenkins::plugin { 'rebuild':
#    version => '1.24',
#  }
##  TODO(jeblair): release
##  jenkins::plugin { 'scp':
##    version => '1.9',
##  }
#  jenkins::plugin { 'simple-theme-plugin':
#    version => '0.3',
#  }
#  jenkins::plugin { 'ssh-agent':
#    version => '1.6',
#  }
#  jenkins::plugin { 'ssh-slaves':
#    version => '1.9',
#  }
#  jenkins::plugin { 'timestamper':
#    version => '1.6',
#  }
#  jenkins::plugin { 'token-macro':
#    version => '1.10',
#  }
#  jenkins::plugin { 'urltrigger':
#    version => '0.37',
#  }
#  jenkins::plugin { 'violations':
#    version => '0.7.11',
#  }
#  jenkins::plugin { 'windows-slaves':
#    version => '1.0',
#  }
#  jenkins::plugin { 'xunit':
#    version => '1.95',
#  }

  if $manage_jenkins_jobs == true {
    class { '::jenkins::job_builder':
      url      => "https://${vhost_name}/",
      username => $jenkins_jobs_username,
      password => $jenkins_jobs_password,
    }

    file { '/etc/jenkins_jobs/config':
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      recurse => true,
      source  =>
        'puppet:///modules/traf/jenkins_job_builder/config',
      notify  => Exec['jenkins_jobs_update'],
    }

    file { '/etc/default/jenkins':
      ensure => present,
      owner  => 'root',
      group  => 'root',
      mode   => '0644',
      source => 'puppet:///modules/traf/jenkins/jenkins.default',
    }
  }

  file { '/etc/sudoers.d/jenkins-sudo-jjb':
    ensure => present,
    source => 'puppet:///modules/traf/jenkins/jenkins-sudo-jjb.sudo',
    owner  => 'root',
    group  => 'root',
    mode   => '0440',
  }

  # Build/test scripts - some small jobs run on jenkins master 
  file { '/usr/local/bin':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    source  => 'puppet:///modules/traf/buildtest',
    recurse => true,
    purge   => false,
  }
  
}
