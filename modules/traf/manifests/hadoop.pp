# == Class: traf::hadoop
#
class traf::hadoop (
  $certname = $::fqdn,
  $hive_sql_pw = '',
  $distro = '',
) {

  # /etc/hosts entries

  host { 'static.trafodion.org':
    ensure       => present,
    host_aliases => 'ldap',
    ip           => '52.27.79.56',
  }

  # new style slave nodes have hostname != certname
  if $certname =~ /^slave-/ {
    # generic slave hostname based on distro
    case $distro {
      'AHW2.1': { $slavename = 'slave-ahw21' }
      'CM5.1':  { $slavename = 'slave-cm51' }
      'AHW2.2': { $slavename = 'slave-ahw22' }
      'CM5.3':  { $slavename = 'slave-cm53' }
      'AHW2.3': { $slavename = 'slave-ahw23' }
      'CM5.4':  { $slavename = 'slave-cm54' }
      'CM5.5':  { $slavename = 'slave-cm55' }
      'CM5.7':  { $slavename = 'slave-cm57' }
      'VH1.0':  { $slavename = 'slave-va10' }
      default:  { $slavename = 'slave' }
    }
    host { "${slavename}.trafodion.org" :
      ensure       => present,
      host_aliases => $slavename,
      ip           => $::ipaddress,
    }
  }

  # For all distros

    class { 'selinux':
      mode => 'disabled',
    }

    # sudo privileged user that can run installer
    # must also be able to ssh to local host
    user::virtual::localuser { 'tinstall':
      realname => 'Trafodion Installer',
      sshkeys  => 'generate',
      groups   => 'sudo',
    }
    file { '/etc/sudoers.d/jenkins-sudo-inst':
      ensure => present,
      source => 'puppet:///modules/traf/jenkins/jenkins-sudo-inst.sudo',
      owner  => 'root',
      group  => 'root',
      mode   => '0440',
    }
    file { '/etc/sudoers.d/jenkins-sudo-regress':
      ensure => present,
      source => 'puppet:///modules/traf/jenkins/jenkins-sudo-regress.sudo',
      owner  => 'root',
      group  => 'root',
      mode   => '0440',
    }

    # json parser for API
    package { 'jq':
      ensure => present,
    }

  # Establish distro parameter for lookup by cluster script
  case $distro {
    'AHW2.1': { $distro_ver = 'HDP-2.1' }
    'AHW2.2': { $distro_ver = 'HDP-2.2' }
    'AHW2.3': { $distro_ver = 'HDP-2.3' }
    'CM5.1':  { $distro_ver = '5.1.4' 
                $hive_schema = '0.12.0' }
    'CM5.3':  { $distro_ver = '5.3.1' 
                $hive_schema = '0.13.0' }
    'CM5.4':  { $distro_ver = '5.4.4' 
                $hive_schema = '1.1.0' }
    'CM5.5':  { $distro_ver = '5.5.4' 
                $hive_schema = '1.1.0' }
    'CM5.7':  { $distro_ver = '5.7.2' 
                $hive_schema = '1.1.0' }
    'VH1.0':  { $distro_ver = '1.0.2' }
    default:  { $distro_ver = 'None' } #cluster script will error out on this
  }
  # Cloudera Manager distros
  if $distro =~ /^CM/ {
    # cluster set-up script
    file { '/usr/local/bin/cluster_setup':
      ensure  => present,
      source  => 'puppet:///modules/traf/hadoop/cmgr.sh',
      owner   => 'root',
      group   => 'root',
      mode    => '0754',
      require => Package['jq'],
    }

    # cloudera module sets up yum repo, but does not install this package
    package { 'hadoop-libhdfs':
      ensure  => present,
      require => Class['::cloudera'],
    }
    # For CDH5, header files are in separate package
    package { 'hadoop-libhdfs-devel':
      ensure  => present,
      require => Class['::cloudera'],
    }
    class { '::cloudera':
      cm_server_host   => 'localhost',
      install_cmserver => true,
      use_parcels      => false,
      cdh_version      => $distro_ver,
    }
    class {'traf::hive_metastore':
      hive_sql_pw     => 'insecure_hive',
      hive_schema_ver => $hive_schema,
      require         => Class['::cloudera'],
    }
  }

  # Ambari managed distros
  if $distro =~ /^AHW/ {
    # cluster set-up script
    file { '/usr/local/bin/cluster_setup':
      ensure  => present,
      source  => 'puppet:///modules/traf/hadoop/amcluster.sh',
      owner   => 'root',
      group   => 'root',
      mode    => '0754',
      require => Package['jq'],
    }

    class { 'traf::ambari' :
      distro => $distro,
    }
  }
  # Vanilla Hadoop
  if $distro =~ /^VH/ {
    # cluster set-up script
    file { '/usr/local/bin/cluster_setup':
      ensure  => present,
      source  => 'puppet:///modules/traf/hadoop/vancluster.sh',
      owner   => 'root',
      group   => 'root',
      mode    => '0754',
    }
    class { 'traf::nondistro' :
      distro => $distro,
    }
  }

  file { '/var/local/TrafTestDistro':
    ensure  => present,
    content => $distro_ver,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
  }

}
