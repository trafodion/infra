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
  $server_path = '/srv/static',
  $download_cipher = hiera('download_cipher'),
  $download_salt = hiera('download_salt'),
  $download_path = '/srv/static/downloads',

) {

  class { 'traf::server':
    iptables_public_tcp_ports => [22, 80, 443],
    rate_unlimit_ips4         => hiera('rate_unlimit_ips'),
    sysadmins                 => $sysadmins,
  }

  include traf
  class { 'jenkins::jenkinsuser':
    ssh_key => $traf::jenkins_ssh_key,
  }

  # add users to jenkins ssh authorized_keys
  $jenkins_auth_users = {
    alchen     =>  { pub_key => $traf::users::alchen_sshkey},
    svarnau    =>  { pub_key => $traf::users::svarnau_sshkey},
    csheedy    =>  { pub_key => $traf::users::csheedy_sshkey},
    johnstac   =>  { pub_key => $traf::users::johnstac_sshkey},
    sandstroms =>  { pub_key => $traf::users::sandstroms_sshkey},
    birdsall   =>  { pub_key => $traf::users::birdsall_sshkey},
  }

  create_resources(jenkins::add_pub_key, $jenkins_auth_users)

  include apache
  include apache::mod::wsgi

  # make sure Curl and PHP is installed
  $packages = ['curl','php5','php5-cli','libapache2-mod-php5','php5-mcrypt','libapache2-mod-xsendfile','lvm2','libjs-jquery','yui-compressor']
  package { $packages:
    ensure  => present,
    require => Package['apache2'],
  }

  a2mod { 'expires':
    ensure  => present,
    require => Package['apache2'],
  }
  a2mod { 'headers':
    ensure  => present,
    require => Package['apache2'],
  }
  a2mod { 'rewrite':
    ensure  => present,
    require => Package['apache2'],
  }
  a2mod { 'proxy':
    ensure  => present,
    require => Package['apache2'],
  }
  a2mod { 'proxy_http':
    ensure  => present,
    require => Package['apache2'],
  }

  file { $server_path:
    ensure => directory,
  }

  ###########################################################
  # www

  apache::vhost { 'www.trafodion.org':
    port          => 80,
    priority      => '01',
    docroot       => $server_path,
    serveraliases => ['trafodion.org', 'www.trafodion.com', 'trafodion.com', '15.125.67.182'],
    template      => 'traf/www.vhost.erb',
  }



  ###########################################################
  # Downloads

  apache::vhost { 'downloads.trafodion.org':
    port     => 80,
    priority => '50',
    docroot  => "${server_path}/downloads-www",
    template => 'traf/downloads/downloads.vhost.erb',
    require  => File["${server_path}/downloads-www"],
  }

  # where download site resides
  file { "${server_path}/downloads-www":
    ensure => directory,
    owner  => 'www-data',
    group  => 'www-data',
  }

  file { "${server_path}/downloads-www/lib":
    ensure  => directory,
    owner   => 'www-data',
    group   => 'www-data',
    require => File["${server_path}/downloads-www"],
  }

  file { "${server_path}/downloads-www/favicon.ico":
    ensure  => present,
    owner   => 'www-data',
    group   => 'www-data',
    source  => 'puppet:///modules/traf/favicon.ico',
    require => File["${server_path}/status"],
  }

  file { "${server_path}/downloads-www/favicon.png":
    ensure  => present,
    owner   => 'www-data',
    group   => 'www-data',
    source  => 'puppet:///modules/traf/favicon.png',
    require => File["${server_path}/downloads-www"],
  }

  file { "${server_path}/downloads-www/index.php":
    ensure  => file,
    owner   => 'www-data',
    group   => 'www-data',
    content => template('traf/downloads/index.php.erb'),
    require => File["${server_path}/downloads-www"],
  }

  file { "${server_path}/downloads-www/getfile.php":
    ensure  => file,
    owner   => 'www-data',
    group   => 'www-data',
    content => template('traf/downloads/getfile.php.erb'),
    require => File["${server_path}/downloads-www"],
  }

  exec { 'get-httpful-phar':
    command => "/usr/bin/curl http://phphttpclient.com/downloads/httpful.phar > ${server_path}/downloads-www/lib/httpful.phar",
    cwd     => "${server_path}/downloads-www/lib",
    creates => "${server_path}/downloads-www/lib/httpful.phar",
    require => [Package['curl'],
                File["${server_path}/downloads-www/lib"]],
  }

  # actual location of files to download
  file { $download_path:
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'jenkins',
    require => User['jenkins'],
  }

  file { "${download_path}/trafodion":
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'jenkins',
    mode    => '0775',
    require => [
      User['jenkins'],
      File[$download_path],
    ]
  }

  file { "${download_path}/trafodion/pre-release":
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'jenkins',
    mode    => '0775',
    require => [
      User['jenkins'],
      File["${download_path}/trafodion"],
    ]
  }

  file { "${download_path}/trafodion/publish":
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'jenkins',
    mode    => '0775',
    require => [
      User['jenkins'],
      File["${download_path}/trafodion"],
    ]
  }

  file { "${download_path}/build-tools-src":
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'jenkins',
    mode    => '0775',
    require => [
      User['jenkins'],
      File[$download_path],
    ]
  }

  file { "${download_path}/build-tool-tgz":
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'jenkins',
    mode    => '0775',
    require => [
      User['jenkins'],
      File[$download_path],
    ]
  }


  ###########################################################
  # Maven repository

  apache::vhost { 'mvnrepo.trafodion.org':
    port     => 80,
    priority => '50',
    docroot  => "${server_path}/mvnrepo",
    require  => File["${server_path}/mvnrepo"],
  }

  file { "${server_path}/mvnrepo":
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
    docroot  => "${server_path}/docs",
    template => 'traf/docs/docs.vhost.erb',
    require  => File["${server_path}/docs"],
  }

  file { "${server_path}/docs":
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'jenkins',
    require => User['jenkins'],
  }


  ###########################################################
  # Logs

  apache::vhost { 'logs.trafodion.org':
    port     => 80,
    priority => '50',
    docroot  => "${server_path}/logs",
    require  => File["${server_path}/logs"],
    template => 'traf/logs.vhost.erb',
  }

  file { "${server_path}/logs":
    ensure  => directory,
    owner   => 'jenkins',
    group   => 'jenkins',
    require => User['jenkins'],
  }

  file { "${server_path}/logs/robots.txt":
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0444',
    source  => 'puppet:///modules/traf/disallow_robots.txt',
    require => File["${server_path}/logs"],
  }

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
    docroot  => "${server_path}/status",
    template => 'traf/status.vhost.erb',
    require  => File["${server_path}/status"],
  }

  file { "${server_path}/status":
    ensure => directory,
  }

  file { "${server_path}/status/index.html":
    ensure  => present,
    source  => 'puppet:///modules/traf/status/index.html',
    require => File["${server_path}/status"],
  }

  file { "${server_path}/status/favicon.ico":
    ensure  => present,
    source  => 'puppet:///modules/traf/favicon.ico',
    require => File["${server_path}/status"],
  }

  file { "${server_path}/status/favicon.png":
    ensure  => present,
    source  => 'puppet:///modules/traf/favicon.png',
    require => File["${server_path}/status"],
  }

  file { "${server_path}/status/common.js":
    ensure  => present,
    source  => 'puppet:///modules/traf/status/common.js',
    require => File["${server_path}/status"],
  }

  file { "${server_path}/status/jquery.min.js":
    ensure  => link,
    target  => '/usr/share/javascript/jquery/jquery.min.js',
    require => [File["${server_path}/status"],
                Package['libjs-jquery']],
  }

  vcsrepo { '/opt/jquery-visibility':
    ensure   => latest,
    provider => git,
    revision => 'master',
    source   => 'https://github.com/mathiasbynens/jquery-visibility.git',
  }

  exec { 'install_jquery-visibility' :
    command     => "yui-compressor -o ${server_path}/status/jquery-visibility.min.js /opt/jquery-visibility/jquery-visibility.js",
    path        => '/bin:/usr/bin',
    refreshonly => true,
    subscribe   => Vcsrepo['/opt/jquery-visibility'],
    require     => [File["${server_path}/status"],
                    Vcsrepo['/opt/jquery-visibility']],
  }

  exec { 'get-jquery-visibility.min':
    command => '/usr/bin/curl https://raw.github.com/mathiasbynens/jquery-visibility/v1.0.6/jquery-visibility.min.js > /opt/jquery-visibility/jquery-visibility.min.js',
    require => [Package['curl'],
                Vcsrepo['/opt/jquery-visibility']],
    cwd     => '/opt/jquery-visibility',
    creates => '/opt/jquery-visibility/jquery-visibility.min.js',
  }

  file { "${server_path}/status/jquery-visibility.min.js":
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

  file { "${server_path}/status/jquery-graphite.js":
    ensure  => link,
    target  => '/opt/jquery-graphite/jquery.graphite.js',
    require => [File["${server_path}/status"],
                Vcsrepo['/opt/jquery-graphite']],
  }

  vcsrepo { '/opt/flot':
    ensure   => latest,
    provider => git,
    revision => 'master',
    source   => 'https://github.com/flot/flot.git',
  }

  exec { 'install_flot' :
    command     => "yui-compressor -o '.js$:.min.js' /opt/flot/jquery.flot*.js; mv /opt/flot/jquery.flot*.min.js ${server_path}/status",
    path        => '/bin:/usr/bin',
    refreshonly => true,
    subscribe   => Vcsrepo['/opt/flot'],
    require     => [File["${server_path}/status"],
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

  file { "${server_path}/status/zuul":
    ensure => directory,
  }

  file { "${server_path}/status/zuul/index.html":
    ensure  => present,
    source  => 'puppet:///modules/traf/zuul/status.html',
    require => File["${server_path}/status/zuul"],
  }

  file { "${server_path}/status/zuul/status.js":
    ensure  => present,
    source  => 'puppet:///modules/traf/zuul/status.js',
    require => File["${server_path}/status/zuul"],
  }

  file { "${server_path}/status/zuul/green.png":
    ensure  => present,
    source  => 'puppet:///modules/traf/zuul/green.png',
    require => File["${server_path}/status/zuul"],
  }

  file { "${server_path}/status/zuul/red.png":
    ensure  => present,
    source  => 'puppet:///modules/traf/zuul/red.png',
    require => File["${server_path}/status/zuul"],
  }

  file { "${server_path}/status/zuul/black.png":
    ensure  => present,
    source  => 'puppet:///modules/traf/zuul/black.png',
    require => File["${server_path}/status/zuul"],
  }

  file { "${server_path}/status/zuul/grey.png":
    ensure  => present,
    source  => 'puppet:///modules/traf/zuul/grey.png',
    require => File["${server_path}/status/zuul"],
  }

  file { "${server_path}/status/zuul/line-angle.png":
    ensure  => present,
    source  => 'puppet:///modules/traf/zuul/line-angle.png',
    require => File["${server_path}/status/zuul"],
  }

  file { "${server_path}/status/zuul/line-t.png":
    ensure  => present,
    source  => 'puppet:///modules/traf/zuul/line-t.png',
    require => File["${server_path}/status/zuul"],
  }

  file { "${server_path}/status/zuul/line.png":
    ensure  => present,
    source  => 'puppet:///modules/traf/zuul/line.png',
    require => File["${server_path}/status/zuul"],
  }

  file { "${server_path}/status/themes":
    ensure  => link,
    target  => "${server_path}/themes",
    require => [File["${server_path}/status"],
                File["${server_path}/themes"]],
  }

  ###########################################################
  # www

  file { "${server_path}/themes":
    ensure  => directory,
    mode    => '0755',
    recurse => true,
  }

  file { "${server_path}/themes/trafodion":
    ensure  => directory,
    mode    => '0755',
    recurse => true,
    require => File["${server_path}/themes"],
  }

  file { "${server_path}/themes/trafodion/images":
    ensure  => directory,
    mode    => '0755',
    recurse => true,
    source  => 'puppet:///modules/traf/images/',
    require => File["${server_path}/themes/trafodion"],
  }

  file { "${server_path}/themes/trafodion/images/Trafodion.png":
    ensure  => present,
    source  => 'puppet:///modules/traf/Trafodion.png',
    require => File["${server_path}/themes/trafodion/images"],
  }

  file { "${server_path}/themes/trafodion/css":
    ensure  => directory,
    mode    => '0755',
    recurse => true,
    require => File["${server_path}/themes/trafodion"],
  }

  vcsrepo { '/opt/blueprint-css':
    ensure   => latest,
    provider => git,
    revision => 'master',
    source   => 'https://github.com/joshuaclayton/blueprint-css.git',
  }

  file { "${server_path}/themes/trafodion/css/blueprint":
    ensure  => link,
    target  => '/opt/blueprint-css/blueprint',
    require => [File["${server_path}/themes/trafodion/css"],
                Vcsrepo['/opt/blueprint-css']],
  }

  file { "${server_path}/themes/trafodion/css/dropdown.css":
    ensure  => present,
    source  => 'puppet:///modules/traf/css/dropdown.css',
    require => File["${server_path}/themes/trafodion/css"],
  }

  file { "${server_path}/themes/trafodion/css/home.css":
    ensure  => present,
    source  => 'puppet:///modules/traf/css/home.css',
    require => File["${server_path}/themes/trafodion/css"],
  }

  file { "${server_path}/themes/trafodion/css/main.css":
    ensure  => present,
    source  => 'puppet:///modules/traf/css/main.css',
    require => File["${server_path}/themes/trafodion/css"],
  }

  # update apache2 security configuration
  exec { 'update security':
    cwd     => '/etc/apache2/conf.d',
    command => "/bin/sed -i -e 's/^ServerTokens .*/ServerTokens Prod/g' security",
    unless  => "/bin/grep -E '^ServerTokens Prod' security",
    notify  => Service[apache2],
  }

  # update apache2 configuration
  # configure MaxClients and MaxRequestsPerChild for 4GB server
  exec { 'update apache2':
    cwd     => '/etc/apache2',
    command => "/bin/sed -i -e 's/^    MaxClients .*/    MaxClients 75/g' -e 's/^    MaxRequestsPerChild .*/    MaxRequestsPerChild 600/g' apache2.conf",
    unless  => "/bin/grep -E '^    MaxClients 75' apache2.conf && /bin/grep -E '^    MaxRequestsPerChild 600' apache2.conf",
    notify  => Service[apache2],
  }

  # update php.ini configuration
  exec { 'update php.ini':
    cwd     => '/etc/php5/apache2',
    command => "/bin/sed -i -e 's/^expose_php = .*/expose_php = Off/g' -e 's/^engine = .*/engine = Off/g' php.ini",
    unless  => "/bin/grep -E '^expose_php = Off' php.ini && /bin/grep -E '^engine = Off' php.ini",
    notify  => Service[apache2],
  }

}
