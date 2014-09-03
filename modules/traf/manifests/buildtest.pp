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
      'perl-Config-IniFiles', 'perl-Config-Tiny', 'perl-DBD-SQLite', 'perl-Expect', 'perl-IO-Tty',
      'perl-Math-Calc-Units','perl-Params-Validate','perl-Parse-RecDescent','perl-TermReadKey',
      'perl-Time-HiRes',
      'python-qpid', 'python-qpid-qmf', 'qpid-cpp-client','qpid-cpp-client-ssl',
      'qpid-cpp-server','qpid-cpp-server-ssl','qpid-qmf','qpid-tools',
      'saslwrapper', 'tog-pegasus', 'uuid-perl','xinetd',
      'readline-devel','alsa-lib-devel',
      'openssl-static','libdrizzle-devel',
      'java-1.6.0-openjdk-devel', 'java-1.7.0-openjdk-devel',
      'ant','ant-nodeps',
      'dos2unix','expect',
      'unixODBC', 'unixODBC-devel', 'libiodbc', 'libiodbc-devel',
      'protobuf-compiler', 'protobuf-devel', 'xerces-c-devel',
      'zlib-devel', 'bzip2-devel', 'ncurses-devel', 'tk-devel', 'gdbm-devel', 'db4-devel', 'libpcap-devel',
    ]

    # Use exec to run yum groupinstall since it is not
    # supported by the package type
    exec { 'install_Development_Tools':
        path    => "/usr/bin:/bin:/usr/local/bin",
        command => 'yum groupinstall "Development Tools"',
        onlyif  => "test `yum grouplist \"Development Tools\" | grep -A 1 \"Installed Groups:\" | grep -c \"Development tools\"` -eq 0",
    }

    package { $packages:
        ensure => present,
        require => [ Exec['install_Development_Tools'] ]
    }

    # not available in latest CentOS distribution, but is in Vault repos
    package { 'qpid-cpp-client-devel':
        ensure => present,
    #    install_options => '--enablerepo=C6.3-updates',
        require => Exec['enable-Vault'],
    }
    # install_options not supported for yum package manager in Puppet 2.7
    # so we enable the repo the hard way
    exec { 'enable-Vault':
      command => "/bin/sed -i '/C6.3-updates/,/^$/s/enabled=0/enabled=1/' /etc/yum.repos.d/CentOS-Vault.repo",
      unless  => '/bin/grep -q "enabled=1" /etc/yum.repos.d/CentOS-Vault.repo',
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

    # This top level dir holds both tar'd up build tool binaries and the untar'd tools.
    # Jenkins write rsync output to this dir.
    file { '/opt/traf' :
      ensure => directory,
      owner  => 'jenkins',
      group  => 'jenkins',
      mode   => '0755',
    }

    # This dir contains the tarballs of the build tool binaries.  Jenkins user 
    # needs to write to this directory to sync the build tools. Do not ensure 
    # mode since the mode of this directory is inherited from rsync
    file { '/opt/traf/build-tool-tgz' :
      ensure  => directory,
      owner   => 'jenkins',
      group   => 'jenkins',
      require => File['/opt/traf'],
    }

    # This dir contains the tools that are used to build Trafodion.
    # We only want root to be able to update this directory.
    file { '/opt/traf/tools' :
      ensure  => directory,
      owner   => 'root',
      group   => 'root',
      mode    => '0755',
      require => File['/opt/traf'],
    }

    # Zero out output file then rsync
    # Sync /opt/traf/tools directory, output gets saved so later we know which files were sync'd.
    # We only untar the files that were sync'd.  That's done in the next step.
    exec { 'rsync-build-tool-tgz' :
      command   => "/bin/cat /dev/null > /opt/traf/rsync.out; /usr/bin/rsync -havS --log-file=/opt/traf/rsync.out --log-file-format=\"%o --- %n\" --del -e \"ssh -o StrictHostKeyChecking=no\" jenkins@downloads.trafodion.org:/srv/static/downloads/build-tool-tgz /opt/traf",
      user      => jenkins,
      provider  => shell,
      onlyif    => "/usr/bin/test `/usr/bin/rsync -haS --dry-run --itemize-changes --del -e \"ssh -o StrictHostKeyChecking=no\" jenkins@downloads.trafodion.org:/srv/static/downloads/build-tool-tgz /opt/traf | /usr/bin/wc -l` -gt 0",
      require   => [ File['/opt/traf/tools'], File['/opt/traf/build-tool-tgz'] ],
    }

    # Un-tar the build tool tarballs, only when tarball has been updated by rsync
    exec { 'untar-build-tool-tgz' :
      command     => '/usr/local/bin/untar_updated_tools.pl -d /opt/traf -f /opt/traf/rsync.out',
      user        => root,
      provider    => shell,
      refreshonly => true,
      subscribe   => Exec['rsync-build-tool-tgz'],
    }
  }
}

