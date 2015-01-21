# == Class: traf::server
#
# A server that we expect to run for some time
class traf::server (
  $iptables_public_tcp_ports = [],
  $iptables_public_udp_ports = [],
  $iptables_rules4           = [],
  $iptables_rules6           = [],
  $rate_unlimit_ips4         = [],
  $rate_unlimit_ips6         = [],
  $ssh_hitcount              = '3',
  $sysadmins                 = [],
  $certname                  = $::fqdn,
) {
  class { 'traf::template':
    iptables_public_tcp_ports => $iptables_public_tcp_ports,
    iptables_public_udp_ports => $iptables_public_udp_ports,
    iptables_rules4           => $iptables_rules4,
    iptables_rules6           => $iptables_rules6,
    rate_unlimit_ips4         => $rate_unlimit_ips4,
    rate_unlimit_ips6         => $rate_unlimit_ips6,
    ssh_hitcount              => $ssh_hitcount,
    certname                  => $certname,
  }
  #class { 'exim':
  #  sysadmin => $sysadmins,
  #}

  if $::osfamily == 'Debian' {
    # Custom rsyslog config to disable /dev/xconsole noise on Debuntu servers
    file { '/etc/rsyslog.d/50-default.conf':
      ensure  => present,
      owner   => 'root',
      group   => 'root',
      mode    => '0644',
      source  =>
        'puppet:///modules/openstack_project/rsyslog.d_50-default.conf',
      replace => true,
    }
    service { 'rsyslog':
      ensure     => running,
      hasrestart => true,
      subscribe  => File['/etc/rsyslog.d/50-default.conf'],
    }

    # Ubuntu installs their whoopsie package by default, but it eats through
    # memory and we don't need it on servers
    package { 'whoopsie':
      ensure => absent,
    }

    # set up vim for root so it understands puppet and ruby files
    # Could not find yum package for this. Debian only.
    package { 'vim-addon-manager':
      ensure => present,
    }
  }
  elsif $::osfamily == 'RedHat' {
    service { 'rsyslog':
      ensure     => running,
      hasrestart => true,
    }
  }

  file { '/root/.vimrc':
    ensure => present,
    source => 'puppet:///modules/traf/vim/_vimrc',
  }

  vcsrepo { '/root/.vim':
    ensure   => latest,
    provider => git,
    revision => 'master',
    owner    => 'root',
    group    => 'root',
    source   => 'https://github.com/trafodion/vim-setup.git',
  }

}
