# == Class: traf::buildtest
#
class traf::buildtest {

  # Build/test scripts
  file { '/usr/local/bin':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
    source => 'puppet:///modules/traf/buildtest',
    recurse => true,
    purge => false,
  }

  # install Maven
  class { 'maven::maven':
    version => '3.0.5',
  }

  # Superset of packages needed for build/test, not installed by default
  if $::osfamily == 'RedHat' {
    $packages = [
      'boost-devel', 'device-mapper-multipath', 'dhcp', 'gd',
      'glibc-devel.i686', 'graphviz-perl', 'libaio-devel',
      'libibcm.i686', 'libibumad-devel', 'libibumad-devel.i686',
      'librdmacm-devel', 'librdmacm-devel.i686',
      'lua-devel', 'lzo-minilzo', 'net-snmp-devel','net-snmp-perl',
      'openldap-clients', 'openldap-devel.i686', 'openmotif','openssl-devel.i686',
      'perl-Config-IniFiles', 'perl-Config-Tiny', 'perl-Expect', 'perl-IO-Tty',
      'perl-Math-Calc-Units','perl-Params-Validate','perl-Parse-RecDescent','perl-TermReadKey',
      'python-qpid', 'python-qpid-qmf', 'qpid-cpp-client','qpid-cpp-client-ssl',
      'qpid-cpp-server','qpid-cpp-server-ssl','qpid-qmf','qpid-tools',
      'qpid-cpp-client-devel',
      'saslwrapper', 'tog-pegasus', 'uuid-perl','xinetd',
      'readline-devel','alsa-lib-devel',
      'openssl-static','libdrizzle-devel',
      'java-1.6.0-openjdk-devel', 'java-1.7.0-openjdk-devel',
      'ant','ant-nodeps',
      'dos2unix','expect',
      'unixODBC.x86_64', 'unixODBC-devel.x86_64',
    ]

    package { $packages:
        ensure => present,
    }
    # Remove bug reporting tool, so we can specify core file pattern
    package {['abrt-cli','abrt-addon-python','abrt-addon-ccpp','abrt-addon-kerneloops','abrt',] :
        ensure => absent,
    }
    exec { 'set corefile pattern' :
        command   => '/sbin/sysctl -w kernel.core_pattern=core.%h.%p.%e',
	    unless    => '/sbin/sysctl -n kernel.core_pattern | grep -q core.%h.%p.%e',
	    require   => Package['abrt'],
    }
    # Turn off randomizing virtual address space
    exec { 'turn off random addr space ' :
        command   => '/sbin/sysctl -w kernel.randomize_va_space=0',
	    provider  => shell,
	    unless    => '[[ $(/sbin/sysctl -n kernel.randomize_va_space) == "0" ]]',
    }
    # Set allowed concurrent requests of asynchronous I/O
    exec { 'set aio-max' :
        command   => '/sbin/sysctl -w fs.aio-max-nr=262144',
	    provider  => shell,
	    unless    => '[[ $(/sbin/sysctl -n fs.aio-max-nr) == "262144" ]]',
    }

    # This top level dir holds both tar'd up build tool binaries and the untar'd tools
    file { '/opt/traf' :
       ensure => directory,
       owner  => 'root',
       group  => 'root',
       mode   => '0755',
    }

    # This dir contains the tarballs of the build tool binaries.  Jenkins user 
    # needs to write to this directory to sync the build tools.
    file { '/opt/traf/build-tool-tgz' :
       ensure  => directory,
       owner   => 'jenkins',
       group   => 'jenkins',
       mode    => '0755',
       require => File['/opt/traf'],
    }

    # This dir contains the tools that are used to build Trafodion
    file { '/opt/traf/tools' :
       ensure  => directory,
       owner   => 'root',
       group   => 'root',
       mode    => '0755',
       require => File['/opt/traf'],
    }

    # This file is created by the rsync-build-tool-tgz step and we don't want rsync
    # to append to an existing output file so we make sure to remove any old copy.
    file { '/opt/traf/build-tool-tgz/rsync.out' :
       ensure  => absent,
       require => File['/opt/traf'],
    }

    # Sync /opt/traf/tools directory, output gets saved so later we know which files were sync'd.
    # We only untar the files that were sync'd.  That's done in the next step.
    exec { 'rsync-build-tool-tgz' :
        command   => '/usr/bin/rsync -havS --log-file=/opt/traf/build-tool-tgz/rsync.out --log-file-format="%o --- %n" --del -e "ssh -o StrictHostKeyChecking=no" jenkins@static.trafodion.org:/srv/static/downloads/build-tool-tgz /opt/traf',
	    user      => jenkins,
	    provider  => shell,
	    require   => [ File['/opt/traf/tools'], File['/opt/traf/build-tool-tgz'], File['/opt/traf/build-tool-tgz/rsync.out'] ],
    }

    # Un-tar the build tool tarballs, only when tarball has been updated by rsync
    exec { 'untar-build-tool-tgz' :
        command   => '/usr/local/bin/untar_updated_tools.pl -d /opt/traf -f /opt/traf/build-tool-tgz/rsync.out',
	    user      => root,
	    provider  => shell,
	    require   => Exec['rsync-build-tool-tgz'],
    }
    
    # python libraries needed by Python Tests
    package { ['unittest2', 'nose', 'pyodbc', 'xmlrunner']:
        ensure   => latest,
        provider => pip,
    }
    
  }
}

