# == Class: traf::jenkins
#
class traf::jenkins (
  $vhost_name = $::fqdn,
  $port = 80,
  $ssl_port = 443,
  $jenkins_jobs_password = '',
  $jenkins_jobs_username = 'JJB',
  $manage_jenkins_jobs = true,
  $ssl_cert_file_contents = '',
  $ssl_key_file_contents = '',
  $ssl_chain_file_contents = '',
  $jenkins_ssh_private_key = '',
  $zmq_event_receivers = [],
  $sysadmins = []
) {
  include traf

  $iptables_rule = regsubst ($zmq_event_receivers, '^(.*)$', '-m state --state NEW -m tcp -p tcp --dport 8888 -s \1 -j ACCEPT')
  class { 'traf::server':
    iptables_public_tcp_ports => [80, 443, 8080],
    iptables_rules6           => $iptables_rule,
    iptables_rules4           => $iptables_rule,
    sysadmins                 => $sysadmins,
  }

  # install rake and puppetlabs_spec_helper from ruby gems
  # so puppet-lint can run on jenkins
  package { 'rake':
    ensure   => latest,
    provider => 'gem',
  }

  package { 'puppetlabs_spec_helper':
    ensure   => latest,
    provider => 'gem',
  }
  # json parser for API
  package { 'jq':
    ensure => present,
  }

  if $ssl_chain_file_contents != '' {
    $ssl_chain_file = '/etc/ssl/certs/intermediate.pem'
  } else {
    $ssl_chain_file = ''
  }

  # set up mount point for jenkins workspaces
  file { '/mnt/jenkins':
    ensure                  => directory,
    mode                    => '0755',
    selinux_ignore_defaults => true,
  }
  # depends on /var/lib/jenkins dir, but specifying it
  # here creates a circular dependency. It must be manually created the first time
  mount { '/var/lib/jenkins':
    ensure  => mounted,
    atboot  => true,
    fstype  => 'none',
    options => 'bind',
    device  => '/mnt/jenkins',
    require => [ File['/mnt/jenkins'] ],
  }

  class { '::jenkins::master':
    vhost_name              => $vhost_name,
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
    require                 => [ Mount['/var/lib/jenkins'] ],
  }

  # jenkins master needs Gerrit's SSL cert
  file { '/usr/local/share/ca-certificates/review.crt':
    ensure  => present,
    content => hiera('gerrit_ssl_cert_file_contents'),
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    notify  => Exec['update-ca-trust'],
  }

  exec { 'update-ca-trust':
    command     => '/usr/sbin/update-ca-certificates; /usr/sbin/update-ca-certificates --fresh',
    refreshonly => true,
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

  # set up jenkins plugins
  jenkins::plugin { 'ansicolor':
    version => '0.4.1',
  }
  jenkins::plugin { 'build-timeout':
    version => '1.14.1',
  }
  jenkins::plugin { 'build-flow-plugin':
    version => '0.17',
  }
  jenkins::plugin { 'conditional-buildstep':
    version => '1.3.3',
  }
  jenkins::plugin { 'copyartifact':
    version => '1.35.1',
  }
  jenkins::plugin { 'dashboard-view':
    version => '2.9.4',
  }
  jenkins::plugin { 'envinject':
    version => '1.90',
  }
  jenkins::plugin { 'zmq-event-publisher':
    version => '0.0.3',
  }
  jenkins::plugin { 'gearman-plugin':
    version => '0.1.1',
  }
  jenkins::plugin { 'git':
    version => '2.3.5',
  }
  jenkins::plugin { 'github-api':
    version => '1.67',
  }
  jenkins::plugin { 'git-client':
    version => '1.17.1',
  }
  jenkins::plugin { 'github-oauth':
    version => '0.20',
  }
  jenkins::plugin { 'github':
    version => '1.11.3',
  }
  jenkins::plugin { 'ghprb':
    version => '1.20.1',
  }
  jenkins::plugin { 'greenballs':
    version => '1.14',
  }
  jenkins::plugin { 'htmlpublisher':
    version => '1.3',
  }
  jenkins::plugin { 'extended-read-permission':
    version => '1.0',
  }
  jenkins::plugin { 'postbuild-task':
    version => '1.8',
  }
  jenkins::plugin { 'jclouds-jenkins':
    version => '2.8',
  }
  jenkins::plugin { 'jobConfigHistory':
    version => '2.11',
  }
  jenkins::plugin { 'mailer':
    version => '1.15',
  }
  jenkins::plugin { 'matrix-auth':
    version => '1.2',
  }
  jenkins::plugin { 'monitoring':
    version => '1.55.0',
  }
  jenkins::plugin { 'jenkins-multijob-plugin':
    version => '1.16',
  }
  jenkins::plugin { 'nodelabelparameter':
    version => '1.5.1',
  }
  jenkins::plugin { 'notification':
    version => '1.9',
  }
  jenkins::plugin { 'parameterized-trigger':
    version => '2.26',
  }
  jenkins::plugin { 'Parameterized-Remote-Trigger':
    version => '2.1.3',
  }
  jenkins::plugin { 'postbuildscript':
    version => '0.17',
  }
  jenkins::plugin { 'publish-over-ftp':
    version => '1.11',
  }
  jenkins::plugin { 'rebuild':
    version => '1.24',
  }
#  TODO(jeblair): release
#  jenkins::plugin { 'scp':
#    version => '1.9',
#  }
  jenkins::plugin { 'simple-theme-plugin':
    version => '0.3',
  }
  jenkins::plugin { 'ssh-agent':
    version => '1.6',
  }
  jenkins::plugin { 'ssh-slaves':
    version => '1.9',
  }
  jenkins::plugin { 'timestamper':
    version => '1.6',
  }
  jenkins::plugin { 'token-macro':
    version => '1.10',
  }
  jenkins::plugin { 'urltrigger':
    version => '0.37',
  }
  jenkins::plugin { 'violations':
    version => '0.7.11',
  }
  jenkins::plugin { 'windows-slaves':
    version => '1.0',
  }
  jenkins::plugin { 'xunit':
    version => '1.95',
  }

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
