# == Class: traf::wiki
#
class traf::wiki (
  $wiki_admin_password = '',
  $mysql_root_password = '',
  $sysadmins = [],
  $ssl_cert_file_contents = '',
  $ssl_key_file_contents = '',
  $ssl_chain_file_contents = ''
) {

  include openssl
  include subversion

  class { 'traf::server':
    iptables_public_tcp_ports => [80, 443],
    sysadmins                 => $sysadmins,
  }

  # wiki admin not in regular sysadmin list
  realize (
    User::Virtual::Localuser['sandstroms'],
  )

  class { 'mediawiki':
    role                      => 'all',
    mediawiki_location        => '/srv/mediawiki/w',
    mediawiki_images_location => '/srv/mediawiki/images',
    server_admin              => 'trafodion-infrastructure@lists.launchpad.net',
    site_hostname             => $::fqdn,
    site_hostname_alias       => "wiki2.${::domain}",
    ssl_cert_file             => "/etc/ssl/certs/${::fqdn}.pem",
    ssl_key_file              => "/etc/ssl/private/${::fqdn}.key",
    ssl_chain_file            => '/etc/ssl/certs/intermediate.pem',
    ssl_cert_file_contents    => $ssl_cert_file_contents,
    ssl_key_file_contents     => $ssl_key_file_contents,
    ssl_chain_file_contents   => $ssl_chain_file_contents,
  }

  class { 'memcached':
    max_memory => 2048,
    listen_ip  => '127.0.0.1',
    tcp_port   => 11000,
    udp_port   => 11000,
  }

  class { 'mysql::server':
    root_password    => $mysql_root_password,
    override_options => {
      'mysqld' => {
        'default-storage-engine' => 'InnoDB',
        'bind_address'           => '127.0.0.1',
      }
    }
  }

  file { '/srv/mediawiki/w/skins/common/images/wiki.png':
      ensure  => present,
      source  => 'puppet:///modules/traf/Trafodion.png',
      owner   => 'www-data',
      group   => 'www-data',
      require => Vcsrepo['/srv/mediawiki/w'],
  }

  file { '/srv/mediawiki/w/favicon.ico':
    ensure  => present,
    mode    => '0644',
    owner   => www-data,
    group   => www-data,
    source  => 'puppet:///modules/traf/favicon.ico',
    require => Vcsrepo['/srv/mediawiki/w'],
  }

  file { '/srv/mediawiki/w/favicon.png':
    ensure  => present,
    mode    => '0644',
    owner   => www-data,
    group   => www-data,
    source  => 'puppet:///modules/traf/favicon.png',
    require => Vcsrepo['/srv/mediawiki/w'],
  }

  # configure mediawiki with default except for the following
  # installdbuser, installdbpass, pass (admin password)
  exec { 'install-mediawiki':
    cwd     => '/srv/mediawiki/w/maintenance',
    command => "/usr/bin/php install.php --installdbuser root --installdbpass \'${mysql_root_password}\' --pass \'${wiki_admin_password}\' Trafodion admin",
    creates => '/srv/mediawiki/w/LocalSettings.php',
    require => Vcsrepo['/srv/mediawiki/w'],
  }

  # install OpenID extension
  vcsrepo { '/srv/mediawiki/w/extensions/OpenID':
    ensure   => present,
    provider => git,
    revision => 'master',
    owner    => www-data,
    group    => www-data,
    source   => 'https://gerrit.wikimedia.org/r/p/mediawiki/extensions/OpenID.git',
    require  => Exec['install-mediawiki'],
  }

  exec { 'install OpenId':
    cwd     => '/srv/mediawiki/w/extensions/OpenID',
    command => "/usr/bin/git clone https://github.com/openid/php-openid.git \
                && /bin/mv php-openid/Auth/ Auth \
                && /bin/rm -rf php-openid \
                && cd /srv/mediawiki/w/maintenance \
                && /usr/bin/php update.php",
    unless  => '/usr/bin/test -d /srv/mediawiki/w/extensions/OpenID/Auth',
    require => Vcsrepo['/srv/mediawiki/w/extensions/OpenID'],
  }

  # install MiniMp3 extension
  file { '/srv/mediawiki/w/extensions/MiniMp3':
    ensure  => directory,
    recurse => true,
    purge   => false,
    owner   => www-data,
    group   => www-data,
    source  => 'puppet:///modules/traf/mediawiki/extensions/MiniMp3',
    require => Exec['install-mediawiki'],
  }

  # install CustomNavBlocks extension
  vcsrepo { '/srv/mediawiki/w/extensions/CustomNavBlocks':
    ensure   => latest,
    provider => git,
    revision => 'master',
    owner    => www-data,
    group    => www-data,
    source   => 'https://github.com/mathiasertl/CustomNavBlocks.git',
    require  => Exec['install-mediawiki'],
  }

  # install UploadLocal extension
  vcsrepo { '/srv/mediawiki/w/extensions/UploadLocal':
    ensure   => present,
    provider => git,
    revision => 'master',
    owner    => www-data,
    group    => www-data,
    source   => 'https://gerrit.wikimedia.org/r/p/mediawiki/extensions/UploadLocal.git',
    require  => Exec['install-mediawiki'],
  }

  # install AddMetas extension
  file { '/srv/mediawiki/w/extensions/AddMetas.php.puppet':
    ensure  => file,
    mode    => '0644',
    owner   => www-data,
    group   => www-data,
    source  => 'puppet:///modules/traf/mediawiki/extensions/AddMetas.php.puppet',
    require => Exec['install-mediawiki'],
  }

  exec { 'update AddMetas.php':
    cwd     => '/srv/mediawiki/w/extensions',
    command => '/bin/cp -p /srv/mediawiki/w/extensions/AddMetas.php.puppet /srv/mediawiki/w/extensions/AddMetas.php',
    unless  => "/bin/grep -E '^# PUPPET ME NOT' /srv/mediawiki/w/extensions/AddMetas.php",
    require => File['/srv'],
  }

  # Fix up LocalSettings.php file and configure mediawiki plugins
  file { '/srv/mediawiki/w/LocalSettings.php':
    ensure  => file,
    mode    => '0600',
    owner   => www-data,
    group   => www-data,
    require => Exec['install OpenId'],
  }

  file { '/srv/mediawiki/w/LocalSettings.php.pupppet':
    mode    => '0600',
    owner   => www-data,
    group   => www-data,
    content => template('traf/LocalSettings.php.erb'),
  }

  exec { 'update LocalSettings.php':
    cwd     => '/srv/mediawiki/w',
    command => '/bin/cp /srv/mediawiki/w/LocalSettings.php.pupppet /srv/mediawiki/w/LocalSettings.php',
    unless  => "/bin/grep -E '^# PUPPET ME NOT' /srv/mediawiki/w/LocalSettings.php",
    require => [ File['/srv/mediawiki/w/LocalSettings.php'], File['/srv/mediawiki/w/LocalSettings.php.pupppet'] ],
  }

  file { '/srv':
    ensure  => directory,
    recurse => true,
    owner   => www-data,
    group   => www-data,
    notify  => Service[apache2],
    require => [
      Exec['install OpenId'],
      File['/srv/mediawiki/w/extensions/MiniMp3'],
      Vcsrepo['/srv/mediawiki/w/extensions/CustomNavBlocks'],
      Vcsrepo['/srv/mediawiki/w/extensions/UploadLocal'],
    ]
  }

  file { '/srv/mediawiki/w/mw-config':
    ensure  => absent,
    force   => true,
    require => File['/srv'],
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
    command => "/bin/sed -i -e 's/^expose_php = .*/expose_php = Off/g' php.ini",
    unless  => "/bin/grep -E '^expose_php = Off' php.ini",
    notify  => Service[apache2],
  }


  include mysql::server::account_security

  mysql_backup::backup { 'wiki':
    hour    => '6',
    require => Class['mysql::server'],
  }

  file { '/usr/local/bin/backupWiki.sh':
    ensure => file,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/traf/mediawiki/backupWiki.sh',
  }

  cron { 'backup-wiki-root':
    user        => 'root',
    hour        => '5',
    minute      => '0',
    weekday     => '0',
    command     => 'sleep $((RANDOM\%600)) && cronic backupWiki.sh',
    environment => 'PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin',
    require     => [
      File['/usr/local/bin/cronic'],
      File['/usr/local/bin/backupWiki.sh'],
      File['/usr/local/bin/useObjectStorage.sh']
    ]
  }

  cron { 'backup-wiki-mysql':
    user        => 'root',
    hour        => '7',
    minute      => '0',
    command     => 'sleep $((RANDOM\%600)) && cronic useObjectStorage.sh -bu /var/backups/mysql_backups/wiki.sql.gz',
    environment => 'PATH=/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin',
    require     => [ File['/usr/local/bin/cronic'], File['/usr/local/bin/useObjectStorage.sh'] ],
  }

  # backup on second node
  #include bup
  #bup::site { 'rs-ord':
  #  backup_user   => 'bup-wiki',
  #  backup_server => 'ci-backup-rs-ord.openstack.org',
  #}
}
