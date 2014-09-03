class traf::dashboard(
    $password = '',
    $mysql_password = '',
    $mysql_innodb_buffer_pool_size = '1536M',
    $sysadmins = []
) {

  class { 'traf::server':
    iptables_public_tcp_ports => [80, 443, 3000],
    sysadmins                 => $sysadmins
  }

  class { '::dashboard':
    dashboard_ensure    => 'present',
    dashboard_user      => 'www-data',
    dashboard_group     => 'www-data',
    dashboard_password  => $password,
    dashboard_db        => 'dashboard_prod',
    dashboard_charset   => 'utf8',
    dashboard_site      => $::fqdn,
    dashboard_port      => '3000',
    mysql_root_pw       => $mysql_password,
    passenger           => true,
  }

  file { '/etc/mysql/conf.d/mysqld_innodb_dashboard.cnf':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('traf/mysqld_innodb_dashboard.cnf.erb'),
    require => Class['mysql::server'],
  }

  file { '/etc/mysql/conf.d/mysqld_innodb_fpt.cnf':
    ensure  => present,
    source  => 'puppet:///modules/openstack_project/dashboard/mysqld_innodb_fpt.cnf',
    require => Class['mysql::server'],
  }

  file { '/etc/default/puppet-dashboard-workers':
    ensure  => file,
    source  => 'puppet:///modules/traf/dashboard/puppet-dashboard-workers',
    require => Class['::dashboard'],
    notify  => Service[puppet-dashboard-workers],
  }

  service { 'puppet-dashboard-workers':
    ensure     => running,
    require    => File['/etc/default/puppet-dashboard-workers'],
    subscribe  => File['/etc/default/puppet-dashboard-workers'],
  }

  # patch /usr/share/puppet-dashboard/lib/tasks/prune_reports.rake to clean up resource_status table
  file { '/usr/share/puppet-dashboard/lib/tasks/prune_reports.rake.patch':
    source  => 'puppet:///modules/traf/dashboard/prune_reports.rake.patch',
    require => Class['::dashboard'],
    notify  => Exec['Apply prune_reports.rake.patch'],
  }

  exec { 'Apply prune_reports.rake.patch':
    cwd         => "/usr/share/puppet-dashboard/lib/tasks",
    command     => "/usr/bin/patch -p0 -N < prune_reports.rake.patch",
    onlyif      => "/usr/bin/patch -p0 -N --dry-run --silent < prune_reports.rake.patch 2>/dev/null",
    refreshonly => true,
  }

  # create cronjob to cleanup the MySQL database
  file { '/usr/share/puppet-dashboard/bin/purgeDashboardDB.sh':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    source  => 'puppet:///modules/traf/dashboard/purgeDashboardDB.sh',
    require => Class['::dashboard'],
  }

  cron { 'purge-dashboard-db':
    environment => 'PATH=/usr/bin:/bin:/usr/sbin:/sbin',
    command     => 'bash /usr/share/puppet-dashboard/bin/purgeDashboardDB.sh',
    user        => 'root',
    hour        => '23',
    minute      => '0',
    ensure      => present,
    require     => File['/usr/share/puppet-dashboard/bin/purgeDashboardDB.sh'],
  }

  # update apache2 security configuration
  exec { 'update security':
    cwd     => "/etc/apache2/conf.d",
    command => "/bin/sed -e 's/^ServerTokens .*/ServerTokens Prod/g' security",
    unless  => "/bin/grep -E '^ServerTokens Prod' security",
    notify  => Service[apache2],
  }

}

# vim:sw=2:ts=2:expandtab:textwidth=79
