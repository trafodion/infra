class traf::cloudeast {
  # /etc/hosts entries

  # internal IP - in US East
  host { 'puppet3.esgyn.com':
    ensure       => present,
    host_aliases => 'puppet3',
    ip           => '172.16.0.46',
  }


  # external IP, dashboard in US West
  host { 'dashboard.esgyn.com':
    ensure       => present,
    host_aliases => 'dashboard',
    ip           => '15.125.67.175',
  }
  host { 'dashboard.trafodion.org':
    ensure       => absent,
  }
}
