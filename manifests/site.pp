
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
    jenkins_jobs_password   => hiera('traf-jenkins_jobs_password'),
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
node /^build$/ {
  include traf
  class { 'traf::slave':
    ssh_key   => $traf::jenkins_ssh_key,
    logs_host => hiera('static_host_key'),
    sysadmins => hiera('sysadmins'),
    distro    => 'None',
    certname  => "build",
  }
}
node /^build7$/ {
  include traf
  class { 'traf::slave':
    ssh_key   => $traf::jenkins_ssh_key,
    logs_host => hiera('static_host_key'),
    sysadmins => hiera('sysadmins'),
    distro    => 'None',
    certname  => "build7",
  }
}

# CMgr
#node /^slave-cm53$/ {
#  include traf
#  class { 'traf::slave':
#    ssh_key   => $traf::jenkins_ssh_key,
#    logs_host => hiera('static_host_key'),
#    sysadmins => hiera('sysadmins'),
#    distro    => 'CM5.3',
#    certname  => "slave-cm53",
#  }
#}
node /^slave-cm54$/ {
  include traf
  class { 'traf::slave':
    ssh_key   => $traf::jenkins_ssh_key,
    logs_host => hiera('static_host_key'),
    sysadmins => hiera('sysadmins'),
    distro    => 'CM5.4',
    certname  => "slave-cm54",
  }
}
# RH7 requires at least CDH5.5
node /^slave7-cm55$/ {
  include traf
  class { 'traf::slave':
    ssh_key   => $traf::jenkins_ssh_key,
    logs_host => hiera('static_host_key'),
    sysadmins => hiera('sysadmins'),
    distro    => 'CM5.5',
    certname  => $name,
  }
}

# Ambari HortonWorks
#node /^slave-ahw22$/ {
#  include traf
#  class { 'traf::slave':
#    ssh_key   => $traf::jenkins_ssh_key,
#    logs_host => hiera('static_host_key'),
#    sysadmins => hiera('sysadmins'),
#    distro    => 'AHW2.2',
#    certname  => "slave-ahw22",
#  }
#}
node /^slave-ahw23$/ {
  include traf
  class { 'traf::slave':
    ssh_key   => $traf::jenkins_ssh_key,
    logs_host => hiera('static_host_key'),
    sysadmins => hiera('sysadmins'),
    distro    => 'AHW2.3',
    certname  => "slave-ahw23",
  }
}
node /^slave-va10$/ {
  include traf
  class { 'traf::slave':
    ssh_key   => $traf::jenkins_ssh_key,
    logs_host => hiera('static_host_key'),
    sysadmins => hiera('sysadmins'),
    distro    => 'VH1.0',
    certname  => "slave-va10",
  }
}


# vim:sw=2:ts=2:expandtab:textwidth=79
