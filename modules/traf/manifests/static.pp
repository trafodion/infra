# == Class: traf::static
#
class traf::static (
  $sysadmins = [],
  $reviewday_gerrit_ssh_key = '',
  $reviewday_rsa_pubkey_contents = '',
  $reviewday_rsa_key_contents = '',
  $releasestatus_prvkey_contents = '',
  $releasestatus_pubkey_contents = '',
  $releasestatus_gerrit_ssh_key = '',
  $er_state_dir = '/var/lib/elastic-recheck',
) {

  class { 'traf::server':
    iptables_public_tcp_ports => [22, 80, 443],
    sysadmins                 => $sysadmins,
  }

  include traf
  class { 'jenkins::jenkinsuser':
    ssh_key => $traf::jenkins_ssh_key,
  }

  # add users to jenkins ssh authorized_keys
  $jenkins_auth_users = {
    alchen     =>  { pub_key => "$traf::users::alchen_sshkey"},
    svarnau    =>  { pub_key => "$traf::users::svarnau_sshkey"},
    sandstroms =>  { pub_key => "$traf::users::sandstroms_sshkey"},
  }

  create_resources(jenkins::add_pub_key, $jenkins_auth_users)

  # make sure Curl is installed
  package { 'curl':
    ensure => present,
  }

  include apache
  include apache::mod::wsgi

  a2mod { 'rewrite':
    ensure => present,
  }
  a2mod { 'proxy':
    ensure => present,
  }
  a2mod { 'proxy_http':
    ensure => present,
  }

  file { '/srv/static':
    ensure => directory,
  }

  ###########################################################
  # www

  apache::vhost { 'www.trafodion.org':
    port          => 80,
    priority      => '01',
    docroot       => '/srv/static',
    serveraliases => ['trafodion.org', 'www.trafodion.com', 'trafodion.com', '15.125.67.182'],
    template      => 'traf/www.vhost.erb',
  }



  ###########################################################
  # Downloads

  apache::vhost { 'downloads.trafodion.org':
    port     => 80,
    priority => '50',
    docroot  => '/srv/static/downloads',
    require  => File['/srv/static/downloads'],
  }

  file { '/srv/static/downloads':
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'jenkins',
    require => User['jenkins'],
  }


  ###########################################################
  # Maven repository

  apache::vhost { 'mvnrepo.trafodion.org':
    port     => 80,
    priority => '50',
    docroot  => '/srv/static/mvnrepo',
    require  => File['/srv/static/mvnrepo'],
  }

  file { '/srv/static/mvnrepo':
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'jenkins',
    require => User['jenkins'],
  }

  file { '/srv/static/downloads/mvnrepo':
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'jenkins',
    require => User['jenkins'],
  }

  file { '/srv/static/downloads/mvnrepo/release':
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'jenkins',
    require => User['jenkins'],
  }

  file { '/srv/static/downloads/mvnrepo/snapshots':
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'jenkins',
    require => User['jenkins'],
  }


  ###########################################################
  # Docs

  apache::vhost { 'docs.trafodion.org':
    port     => 80,
    priority => '50',
    docroot  => '/srv/static/docs',
    require  => File['/srv/static/docs'],
  }

  file { '/srv/static/docs':
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'jenkins',
    require => User['jenkins'],
  }

  file { '/srv/static/docs/robots.txt':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0444',
    source  => 'puppet:///modules/openstack_project/disallow_robots.txt',
    require => File['/srv/static/docs'],
  }


  ###########################################################
  # Logs

  apache::vhost { 'logs.trafodion.org':
    port     => 80,
    priority => '50',
    docroot  => '/srv/static/logs',
    require  => File['/srv/static/logs'],
    template => 'openstack_project/logs.vhost.erb',
  }

  file { '/srv/static/logs':
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'jenkins',
    require => User['jenkins'],
  }

  file { '/srv/static/logs/robots.txt':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0444',
    source  => 'puppet:///modules/openstack_project/disallow_robots.txt',
    require => File['/srv/static/logs'],
  }

  vcsrepo { '/opt/os-loganalyze':
    ensure   => latest,
    provider => git,
    revision => 'master',
    source   => 'https://git.openstack.org/openstack-infra/os-loganalyze',
  }

  exec { 'install_os-loganalyze':
    command     => 'python setup.py install',
    cwd         => '/opt/os-loganalyze',
    path        => '/bin:/usr/bin',
    refreshonly => true,
    subscribe   => Vcsrepo['/opt/os-loganalyze'],
  }

  ## os-loganalyze will replace htmlify
  file { '/usr/local/bin/htmlify-screen-log.py':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    source  => 'puppet:///modules/openstack_project/logs/htmlify-screen-log.py',
  }

#  No log help files for Trafodion.
#  file { '/srv/static/logs/help':
#    ensure  => directory,
#    recurse => true,
#    purge   => true,
#    force   => true,
#    owner   => 'root',
#    group   => 'root',
#    mode    => '0755',
#    source  => 'puppet:///modules/traf/logs/help',
#    require => File['/srv/static/logs'],
#  }

  file { '/usr/local/sbin/log_archive_maintenance.sh':
    ensure => present,
    owner  => 'root',
    group  => 'root',
    mode   => '0744',
    source => 'puppet:///modules/traf/log_archive_maintenance.sh',
  }

  cron { 'gziprmlogs':
    user        => 'root',
    minute      => '0',
    hour        => '7',
    weekday     => '*',
    command     => 'bash /usr/local/sbin/log_archive_maintenance.sh',
    environment => 'PATH=/usr/bin:/bin:/usr/sbin:/sbin',
    require     => File['/usr/local/sbin/log_archive_maintenance.sh'],
  }

  ###########################################################
  # Status

  apache::vhost { 'status.trafodion.org':
    port     => 80,
    priority => '50',
    docroot  => '/srv/static/status',
    template => 'openstack_project/status.vhost.erb',
    require  => File['/srv/static/status'],
  }

  file { '/srv/static/status':
    ensure => directory,
  }

  package { 'libjs-jquery':
    ensure => present,
  }

  package { 'yui-compressor':
    ensure => present,
  }

  file { '/srv/static/status/index.html':
    ensure  => present,
    source  => 'puppet:///modules/traf/status/index.html',
    require => File['/srv/static/status'],
  }

  file { '/srv/static/status/favicon.ico':
    ensure  => present,
    source  => 'puppet:///modules/traf/status/favicon.ico',
    require => File['/srv/static/status'],
  }

  file { '/srv/static/status/common.js':
    ensure  => present,
    source  => 'puppet:///modules/traf/status/common.js',
    require => File['/srv/static/status'],
  }

  file { '/srv/static/status/jquery.min.js':
    ensure  => link,
    target  => '/usr/share/javascript/jquery/jquery.min.js',
    require => [File['/srv/static/status'],
                Package['libjs-jquery']],
  }

  vcsrepo { '/opt/jquery-visibility':
    ensure   => latest,
    provider => git,
    revision => 'master',
    source   => 'https://github.com/mathiasbynens/jquery-visibility.git',
  }

  exec { 'install_jquery-visibility' :
    command     => 'yui-compressor -o /srv/static/status/jquery-visibility.min.js /opt/jquery-visibility/jquery-visibility.js',
    path        => '/bin:/usr/bin',
    refreshonly => true,
    subscribe   => Vcsrepo['/opt/jquery-visibility'],
    require     => [File['/srv/static/status'],
                    Vcsrepo['/opt/jquery-visibility']],
  }

  exec { 'get-jquery-visibility.min':
    command     => '/usr/bin/curl https://raw.github.com/mathiasbynens/jquery-visibility/v1.0.6/jquery-visibility.min.js > /opt/jquery-visibility/jquery-visibility.min.js',
    require     => [Package['curl'],
                    Vcsrepo['/opt/jquery-visibility']],
    cwd         => '/opt/jquery-visibility',
  }

  file { '/srv/static/status/jquery-visibility.min.js':
    ensure  => link,
    target  => '/opt/jquery-visibility/jquery-visibility.min.js',
    require => Vcsrepo['/opt/jquery-visibility'],
  }

  vcsrepo { '/opt/jquery-graphite':
    ensure   => latest,
    provider => git,
    revision => 'master',
    source   => 'https://github.com/prestontimmons/graphitejs.git',
  }

  file { '/srv/static/status/jquery-graphite.js':
    ensure  => link,
    target  => '/opt/jquery-graphite/jquery.graphite.js',
    require => [File['/srv/static/status'],
                Vcsrepo['/opt/jquery-graphite']],
  }

  vcsrepo { '/opt/flot':
    ensure   => latest,
    provider => git,
    revision => 'master',
    source   => 'https://github.com/flot/flot.git',
  }

  exec { 'install_flot' :
    command     => 'yui-compressor -o \'.js$:.min.js\' /opt/flot/jquery.flot*.js; mv /opt/flot/jquery.flot*.min.js /srv/static/status',
    path        => '/bin:/usr/bin',
    refreshonly => true,
    subscribe   => Vcsrepo['/opt/flot'],
    require     => [File['/srv/static/status'],
                    Vcsrepo['/opt/flot']],
  }

  ###########################################################
  # Status - elastic-recheck

  include elastic_recheck

  cron { 'elastic-recheck':
    user        => 'recheck',
    minute      => '*/15',
    hour        => '*',
    command     => "elastic-recheck-graph /opt/elastic-recheck/queries -o ${er_state_dir}/graph-new.json && mv ${er_state_dir}/graph-new.json ${er_state_dir}/graph.json",
    environment => 'PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin',
    require     => Class['elastic_recheck']
  }

  ###########################################################
  # Status - zuul

  file { '/srv/static/status/zuul':
    ensure => directory,
  }

  file { '/srv/static/status/zuul/index.html':
    ensure  => present,
    source  => 'puppet:///modules/traf/zuul/status.html',
    require => File['/srv/static/status/zuul'],
  }

  file { '/srv/static/status/zuul/status.js':
    ensure  => present,
    source  => 'puppet:///modules/traf/zuul/status.js',
    require => File['/srv/static/status/zuul'],
  }

  file { '/srv/static/status/zuul/green.png':
    ensure  => present,
    source  => 'puppet:///modules/traf/zuul/green.png',
    require => File['/srv/static/status/zuul'],
  }

  file { '/srv/static/status/zuul/red.png':
    ensure  => present,
    source  => 'puppet:///modules/traf/zuul/red.png',
    require => File['/srv/static/status/zuul'],
  }

  file { '/srv/static/status/zuul/line-angle.png':
    ensure  => present,
    source  => 'puppet:///modules/traf/zuul/line-angle.png',
    require => File['/srv/static/status/zuul'],
  }

  file { '/srv/static/status/zuul/line-t.png':
    ensure  => present,
    source  => 'puppet:///modules/traf/zuul/line-t.png',
    require => File['/srv/static/status/zuul'],
  }

  file { '/srv/static/status/zuul/line.png':
    ensure  => present,
    source  => 'puppet:///modules/traf/zuul/line.png',
    require => File['/srv/static/status/zuul'],
  }

  ###########################################################
  # www 

  file { '/srv/static/themes':
    ensure  => directory,
    mode    => 0755,
    recurse => true,
  }

  file { '/srv/static/themes/trafodion':
    ensure  => directory,
    mode    => 0755,
    recurse => true,
    require => File['/srv/static/themes'],
  }

  file { '/srv/static/themes/trafodion/images':
    ensure  => directory,
    mode    => 0755,
    recurse => true,
    source  => 'puppet:///modules/traf/images/',
    require => File['/srv/static/themes/trafodion'],
  }

  file { '/srv/static/themes/trafodion/images/Trafodion.png':
    ensure  => present,
    source  => 'puppet:///modules/traf/Trafodion.png',
    require => File['/srv/static/themes/trafodion/images'],
  }

  file { '/srv/static/themes/trafodion/css':
    ensure  => directory,
    mode    => 0755,
    recurse => true,
    require => File['/srv/static/themes/trafodion'],
  }

  vcsrepo { '/opt/blueprint-css':
    ensure   => latest,
    provider => git,
    revision => 'master',
    source   => 'https://github.com/joshuaclayton/blueprint-css.git',
  }

  file { '/srv/static/themes/trafodion/css/blueprint':
    ensure  => link,
    target  => '/opt/blueprint-css/blueprint',
    require => [File['/srv/static/themes/trafodion/css'],
                Vcsrepo['/opt/blueprint-css']],
  }

  file { '/srv/static/themes/trafodion/css/dropdown.css':
    ensure  => present,
    source  => 'puppet:///modules/traf/css/dropdown.css',
    require => File['/srv/static/themes/trafodion/css'],
  }

  file { '/srv/static/themes/trafodion/css/home.css':
    ensure  => present,
    source  => 'puppet:///modules/traf/css/home.css',
    require => File['/srv/static/themes/trafodion/css'],
  }

  file { '/srv/static/themes/trafodion/css/main.css':
    ensure  => present,
    source  => 'puppet:///modules/traf/css/main.css',
    require => File['/srv/static/themes/trafodion/css'],
  }

  # need LVM to manage the big directories like downloads
  package { 'lvm2':
    ensure => present,
  }

}
