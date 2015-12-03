
# default puppet-master
$pserver='puppet'

#
# Default: at least puppet running regularly and sysadmin access
#
node default {
  class { 'traf::server':
    sysadmins => hiera('sysadmins'),
  }
}


# Jenkins master
node /jenkins/ {
  class { 'traf::jenkins':
    vhost_alias             => ['jenkins.esgyn.com','traf-jenkins.esgyn.com'],
    jenkins_jobs_username   => 'Traf-Jenkins',
    jenkins_jobs_password   => hiera('jenkins02_jobs_password'),
    jenkins_ssh_private_key => hiera('jenkins_ssh_private_key_contents'),
    ssl_cert_file_contents  => hiera('jenkins_ssl_cert_file_contents'),
    ssl_key_file_contents   => hiera('jenkins_ssl_key_file_contents'),
    ssl_chain_file_contents => hiera('jenkins_ssl_chain_file_contents'),
    sysadmins               => hiera('sysadmins'),
  }
}

# New master running puppet 3.x
node /^puppet*/ {
  class { 'traf::puppetmaster':
    sysadmins         => hiera('sysadmins'),
  }
}

# A machine to serve static content.
# For instance, domain home page, ftp server, etc.
node /^static*/ {
  class { 'traf::static':
    sysadmins                     => hiera('sysadmins'),
  }
}


# LDAP server config
node /^ldap\d\d.trafodion.org$/ {
  class { 'traf::ldap':
    sysadmins         => hiera('sysadmins'),
  }
}

# Dev servers
node /^adev\d\d*/ {
  include traf
  class { 'traf::dev':
    sysadmins       => hiera('sysadmins'),
    jenkins_ssh_key => hiera('jenkins_ssh_pub_key_contents'),
  }
}

# hands-on test machines
node /^mtest\d\d.trafodion.org$/ {
  include traf
  class { 'traf::testm':
    sysadmins => hiera('sysadmins'),
  }
}

#
# Jenkins slaves:
#

# Build Server
node /^build\d\d.trafodion.org$/ {
  include traf
  class { 'traf::slave':
    ssh_key   => $traf::jenkins_ssh_key,
    logs_host => hiera('static_host_key'),
    sysadmins => hiera('sysadmins'),
    distro    => 'None',
  }
}

# CMgr
node /^slave-cm51-\d\d.trafodion.org$/ {
  include traf
  class { 'traf::slave':
    ssh_key   => $traf::jenkins_ssh_key,
    logs_host => hiera('static_host_key'),
    sysadmins => hiera('sysadmins'),
    distro    => 'CM5.1',
  }
}
node /^slave-cm51-\d+\.\d+\.\d+\.\d+$/ {
  include traf
  class { 'traf::slave':
    ssh_key   => $traf::jenkins_ssh_key,
    logs_host => hiera('static_host_key'),
    sysadmins => hiera('sysadmins'),
    distro    => 'CM5.1',
    certname  => "slave-cm51-${::ipaddress}",
  }
}
node /^slave-cm53-\d\d.trafodion.org$/ {
  include traf
  class { 'traf::slave':
    ssh_key   => $traf::jenkins_ssh_key,
    logs_host => hiera('static_host_key'),
    sysadmins => hiera('sysadmins'),
    distro    => 'CM5.3',
  }
}
node /^slave-cm53-\d+\.\d+\.\d+\.\d+$/ {
  include traf
  class { 'traf::slave':
    ssh_key   => $traf::jenkins_ssh_key,
    logs_host => hiera('static_host_key'),
    sysadmins => hiera('sysadmins'),
    distro    => 'CM5.3',
    certname  => "slave-cm53-${::ipaddress}",
  }
}
node /^slave-cm54-\d+\.\d+\.\d+\.\d+$/ {
  include traf
  class { 'traf::slave':
    ssh_key   => $traf::jenkins_ssh_key,
    logs_host => hiera('static_host_key'),
    sysadmins => hiera('sysadmins'),
    distro    => 'CM5.4',
    certname  => "slave-cm54-${::ipaddress}",
  }
}

# Ambari HortonWorks
node /^slave-ahw21-\d\d.trafodion.org$/ {
  include traf
  class { 'traf::slave':
    ssh_key   => $traf::jenkins_ssh_key,
    logs_host => hiera('static_host_key'),
    sysadmins => hiera('sysadmins'),
    distro    => 'AHW2.1',
  }
}
node /^slave-ahw21-\d+\.\d+\.\d+\.\d+$/ {
  include traf
  class { 'traf::slave':
    ssh_key   => $traf::jenkins_ssh_key,
    logs_host => hiera('static_host_key'),
    sysadmins => hiera('sysadmins'),
    distro    => 'AHW2.1',
    certname  => "slave-ahw21-${::ipaddress}",
  }
}
node /^slave-ahw22-\d\d.trafodion.org$/ {
  include traf
  class { 'traf::slave':
    ssh_key   => $traf::jenkins_ssh_key,
    logs_host => hiera('static_host_key'),
    sysadmins => hiera('sysadmins'),
    distro    => 'AHW2.2',
  }
}
node /^slave-ahw22-\d+\.\d+\.\d+\.\d+$/ {
  include traf
  class { 'traf::slave':
    ssh_key   => $traf::jenkins_ssh_key,
    logs_host => hiera('static_host_key'),
    sysadmins => hiera('sysadmins'),
    distro    => 'AHW2.2',
    certname  => "slave-ahw22-${::ipaddress}",
  }
}
node /^slave-ahw23-\d+\.\d+\.\d+\.\d+$/ {
  include traf
  class { 'traf::slave':
    ssh_key   => $traf::jenkins_ssh_key,
    logs_host => hiera('static_host_key'),
    sysadmins => hiera('sysadmins'),
    distro    => 'AHW2.3',
    certname  => "slave-ahw23-${::ipaddress}",
  }
}


# vim:sw=2:ts=2:expandtab:textwidth=79
