class traf::dashboard(
    $password = '',
    $mysql_password = '',
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

  file { '/etc/mysql/conf.d/mysqld_innodb_fpt.cnf':
    ensure  => present,
    source  => 'puppet:///modules/openstack_project/dashboard/mysqld_innodb_fpt.cnf',
    require => Class['mysql::server'],
  }

  file { '/etc/default/puppet-dashboard-workers':
    ensure  => file,
    source  => 'puppet:///modules/traf/dashboard/puppet-dashboard-workers',
    require => Class['::dashboard'],
    notify  => Service[puppet-dashboard-workers]
  }

  service { 'puppet-dashboard-workers':
      ensure  => running,
      require => File['/etc/default/puppet-dashboard-workers'],
      subscribe  => File['/etc/default/puppet-dashboard-workers'],
  }
}

# vim:sw=2:ts=2:expandtab:textwidth=79
