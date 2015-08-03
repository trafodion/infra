class traf::cloudwest {
  # /etc/hosts entries

  # external IP - in US East
  host { 'puppet3.esgyn.com':
    ensure       => present,
    host_aliases => 'puppet3',
    ip           => '15.126.214.121',
  }

  # internal IP, dashboard in US West
  host { 'dashboard.esgyn.com':
    ensure       => present,
    host_aliases => 'dashboard',
    ip           => '192.168.0.31',
  }
  host { 'dashboard.trafodion.org':
    ensure       => absent,
  }
}
