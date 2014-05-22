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

  # Tune MySQL max_allowed_packet to 32M or greater
  exec { 'up mysql max_allowed_packet':
    command => "/bin/sed -i.bak -e 's/^max_allowed_packet =.*/max_allowed_packet = 32M/g' /etc/mysql/my.cnf",
    unless  => "/bin/grep -E '^max_allowed_packet = ([3456789][23456789]|[1-9][0-9]{2,})M' /etc/mysql/my.cnf",
    require => File['/etc/mysql/my.cnf'],
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
}

# vim:sw=2:ts=2:expandtab:textwidth=79
