# == Class: traf::static
#
class traf::static (
  $sysadmins = [],
  $server_path = '/srv/static',
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

  class { 'selinux':
    mode => 'disabled',
  }

  class { 'apache':
   server_tokens => 'Prod',
   server_signature => 'Off',
  }
  #class { 'apache::mod::event':
  # maxclients             => '75',
  # maxconnectionsperchild => '600',
  #}
  include apache::mod::wsgi
  #include apache::mod::expires
  #include apache::mod::headers
  include apache::mod::rewrite
  #include apache::mod::proxy
  #include apache::mod::proxy_http
  include apache::mod::deflate
  class { 'apache::mod::php':
  }


  # make sure Curl and PHP is installed
  $packages = ['curl','php']
  package { $packages:
    ensure  => present,
    require => Package['httpd'],
  }

  file { $server_path:
    ensure => directory,
  }

  ###########################################################
  # www -- send them to Apache trafodion project page

  apache::vhost { 'www.trafodion.org':
    port            => 80,
    priority        => '01',
    docroot         => $server_path,
    serveraliases   => ['trafodion.org', 'www.trafodion.com', 'trafodion.com', '15.125.67.182'],
    redirect_source => '/',
    redirect_status => 'permanent',
    redirect_dest   => 'http://trafodion.incubator.apache.org/',
  }



  ###########################################################
  # Downloads

  apache::vhost { 'traf-builds.esgyn.com':
    serveraliases => "downloads.trafodion.org",
    port          => 80,
    priority      => '50',
    docroot       => "${server_path}/downloads-www",
    directories   => [
      { path         => '\.php$',
        provider     => 'filesmatch',
        handler      => 'application/x-httpd-php',
      },
      { path         => "${server_path}/downloads-www",
        provider     => 'directory',
	override     => ['None'],
	options      => ['Indexes','FollowSymLinks','MultiViews'],
	order        => 'Allow,Deny',
	allow        => 'from all',
      },
    ],
    setenv        => ['no-gzip dont-vary'],
    require       => File["${server_path}"],
  }

  # where download site resides 
  file { "${server_path}/downloads-www":
    ensure => directory,
    owner  => 'apache',
    group  => 'apache',
  }
  file { "${server_path}/downloads-www/downloads":
    ensure => link,
    target  => "${server_path}/downloads",
    owner  => 'apache',
    group  => 'apache',
    mode    => '0775',
  }

  file { "${server_path}/downloads-www/lib":
    ensure  => directory,
    owner   => 'apache',
    group   => 'apache',
    require => File["${server_path}/downloads-www"],
  }

  file { "${server_path}/downloads-www/favicon.ico":
    ensure  => present,
    owner   => 'apache',
    group   => 'apache',
    source  => 'puppet:///modules/traf/favicon.ico',
    require => File["${server_path}/downloads-www"],
  }

  file { "${server_path}/downloads-www/favicon.png":
    ensure  => present,
    owner   => 'apache',
    group   => 'apache',
    source  => 'puppet:///modules/traf/favicon.png',
    require => File["${server_path}/downloads-www"],
  }

  file { "${server_path}/downloads-www/index.php":
    ensure  => file,
    owner   => 'apache',
    group   => 'apache',
    content => template('traf/downloads/index.php.erb'),
    require => File["${server_path}/downloads-www"],
  }

  ## pull files from HP-Cloud CDN
  #file { "${server_path}/downloads-www/getfile.php":
  #  ensure  => file,
  #  owner   => 'apache',
  #  group   => 'apache',
  #  content => template('traf/downloads/getfile.php.erb'),
  #  require => File["${server_path}/downloads-www"],
  #}

  file { "${server_path}/downloads-www/common.js":
    ensure  => present,
    source  => 'puppet:///modules/traf/status/common.js',
    require => File["${server_path}/downloads-www"],
  }

  file { "${server_path}/downloads-www/themes":
    ensure  => link,
    target  => "${server_path}/themes",
    require => [File["${server_path}/downloads-www"],
                File["${server_path}/themes"]],
  }

#  exec { 'get-httpful-phar':
#    command => "/usr/bin/curl http://phphttpclient.com/downloads/httpful.phar > ${server_path}/downloads-www/lib/httpful.phar",
#    cwd     => "${server_path}/downloads-www/lib",
#    creates => "${server_path}/downloads-www/lib/httpful.phar",
#    require => [Package['curl'],
#                File["${server_path}/downloads-www/lib"]],
#  }

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
  # Docs

#  apache::vhost { 'docs.trafodion.org':
#    port     => 80,
#    priority => '50',
#    docroot  => "${server_path}/docs",
#    template => 'traf/docs/docs.vhost.erb',
#    require  => File["${server_path}/docs"],
#  }
#
#  file { "${server_path}/docs":
#    ensure  => directory,
#    owner   => 'jenkins',
#    group   => 'jenkins',
#    require => User['jenkins'],
#  }


  ###########################################################
  # Logs

  apache::vhost { 'traf-testlogs.esgyn.com':
    serveraliases       => "logs.trafodion.org",
    port                => 80,
    priority            => '50',
    docroot             => "${server_path}/logs",
    directories         => [
      { path                => '\.html\.gz$',
        provider            => 'filesmatch',
	force_type          => 'text/html',
	add_default_charset => 'UTF-8',
	custom_fragment     => 'AddEncoding x-gzip gz',
      },
      { path                => "${server_path}/logs",
        provider            => 'directory',
	override            => ['None'],
	options             => ['Indexes','FollowSymLinks','MultiViews'],
	order               => 'Allow,Deny',
	allow               => 'from all',
      },
    ],
    rewrites            => [
      { comment             => 'rewrite all txt.gz & html.gz files to map to our internal htmlify wsgi app',
        rewrite_rule        => ['^/(.*\.txt\.gz)$ /htmlify/$1 [QSA,L,PT]',
                                '^/(.*console\.html(\.gz)?)$ /htmlify/$1 [QSA,L,PT]'],
      },
    ],
    wsgi_script_aliases => { '/htmlify' => '/usr/local/lib/python2.7/dist-packages/os_loganalyze/wsgi.py' },
    require             => File["${server_path}/logs"],
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
#
#  file { "${server_path}/themes/trafodion/css/dropdown.css":
#    ensure  => present,
#    source  => 'puppet:///modules/traf/css/dropdown.css',
#    require => File["${server_path}/themes/trafodion/css"],
#  }
#
#  file { "${server_path}/themes/trafodion/css/home.css":
#    ensure  => present,
#    source  => 'puppet:///modules/traf/css/home.css',
#    require => File["${server_path}/themes/trafodion/css"],
#  }
#
#  file { "${server_path}/themes/trafodion/css/main.css":
#    ensure  => present,
#    source  => 'puppet:///modules/traf/css/main.css',
#    require => File["${server_path}/themes/trafodion/css"],
#  }


#  # update php.ini configuration
#  exec { 'update php.ini':
#    cwd     => '/etc/php5/apache2',
#    command => "/bin/sed -i -e 's/^expose_php = .*/expose_php = Off/g' -e 's/^engine = .*/engine = Off/g' php.ini",
#    unless  => "/bin/grep -E '^expose_php = Off' php.ini && /bin/grep -E '^engine = Off' php.ini",
#    notify  => Service[httpd],
#  }

}
