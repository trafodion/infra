# == Class: traf::buildtest
#
class traf::buildtest (
  $jenkins_test_user = hiera('jenkins_test_user', 'dontcare'),
  $jenkins_test_password = hiera('jenkins_test_password', 'dontcare'),
) {

  # Build/test scripts
  file { '/usr/local/bin':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    source  => 'puppet:///modules/traf/buildtest',
    recurse => true,
    purge   => false,
  }

  file { '/usr/local/bin/run-jdbc_test.sh':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => template('traf/buildtest/run-jdbc_test.sh.erb'),
    require => File['/usr/local/bin'],
  }

  file { '/usr/local/bin/run-phoenix_test.sh':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => template('traf/buildtest/run-phoenix_test.sh.erb'),
    require => File['/usr/local/bin'],
  }

  file { '/usr/local/bin/run-pyodbc_test.sh':
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => template('traf/buildtest/run-pyodbc_test.sh.erb'),
    require => File['/usr/local/bin'],
  }

  # install Maven
  class { 'maven::maven':
    version => '3.6.3',
  }

  # Superset of packages needed for build/test, not installed by default
  if $::osfamily == 'RedHat' {
    $packages = [
      'boost-devel', 'device-mapper-multipath', 'dhcp', 'gd', 'apr-devel', 'apr-util',
      'glibc-devel.i686', 'graphviz-perl', 'libaio-devel',
      'libibcm.i686', 'libibumad-devel', 'libibumad-devel.i686',
      'librdmacm-devel', 'librdmacm-devel.i686',
      'lua-devel', 'lzo-minilzo', 'net-snmp-devel','net-snmp-perl',
      'openldap-clients', 'openldap-devel.i686', 'openssl-devel.i686',
      'perl-Config-IniFiles', 'perl-Config-Tiny', 'perl-DBD-SQLite', 'perl-Expect', 'perl-IO-Tty',
      'perl-Math-Calc-Units','perl-Params-Validate','perl-Parse-RecDescent','perl-TermReadKey',
      'perl-Time-HiRes',
      'saslwrapper', 'tog-pegasus', 'uuid-perl','xinetd',
      'readline-devel','alsa-lib-devel',
      'openssl-static',
      'java-1.7.0-openjdk-devel', 'java-1.8.0-openjdk-devel',
      'ant',
      'dos2unix','expect',
      'unixODBC', 'unixODBC-devel', 'libiodbc', 'libiodbc-devel',
      'protobuf-compiler', 'protobuf-devel', 'xerces-c-devel',
      'zlib-devel', 'bzip2-devel', 'ncurses-devel', 'tk-devel', 'gdbm-devel', 'libpcap-devel',
      'cmake','npm',
      'lzo','lzop','lzo-devel',
      'doxygen',
      'libuuid-devel',
    ]
    if $::operatingsystemmajrelease == '7' {
      package { ['motif','libdb4-devel']:
        ensure  => present,
      }
    } elsif $::operatingsystemmajrelease == '6' {
      package { ['openmotif','db4-devel','ant-nodeps']:
        ensure  => present,
      }
    }

    exec { 'install_bower':
        path    => '/usr/bin:/bin:/usr/local/bin',
        command => 'npm install -g bower',
        onlyif  => "npm ls -g bower | grep '(empty)'",
	require => Package['npm'],
    }

    # Use exec to run yum groupinstall since it is not
    # supported by the package type
    exec { 'install_Development_Tools':
        path    => '/usr/bin:/bin:/usr/local/bin',
        command => 'yum -y groupinstall "Development Tools"',
        onlyif  => "test `yum grouplist \"Development Tools\" | grep -A 1 \"Installed Groups:\" | grep -ic \"Development tools\"` -eq 0",
    }

    package { $packages:
        ensure  => present,
        require => [ Exec['install_Development_Tools'] ]
    }

    # Remove bug reporting tool, so we can specify core file pattern
    package {['abrt-python','abrt-cli','abrt-addon-python','abrt-addon-ccpp','abrt-addon-kerneloops','abrt',] :
      ensure => absent,
    }
    exec { 'set corefile pattern' :
      command => '/sbin/sysctl -w kernel.core_pattern=core.%h.%p.%e',
      unless  => '/sbin/sysctl -n kernel.core_pattern | grep -q core.%h.%p.%e',
      require => Package['abrt'],
    }
    # link perms for saving workspaces
    if $::operatingsystemmajrelease == '7' {
      sysctl { "fs.protected_hardlinks":
        ensure => present,
        value  => "0",
      }
      sysctl { "fs.protected_symlinks":
        ensure => present,
        value  => "0",
      }
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

    if $::operatingsystemmajrelease == '7' {
      $toolsrc = '/srv/static/downloads/build-tool-rh7'
    } elsif $::operatingsystemmajrelease == '6' {
      $toolsrc = '/srv/static/downloads/build-tool-tgz'
    }
    # Zero out output file then rsync
    # Sync /opt/traf/tools directory, output gets saved so later we know which files were sync'd.
    # We only untar the files that were sync'd.  That's done in the next step.
    exec { 'rsync-build-tool-tgz' :
      command  => "/bin/cat /dev/null > /opt/traf/rsync.out; /usr/bin/rsync -havS --log-file=/opt/traf/rsync.out --log-file-format=\"%o --- %n\" --del -e \"ssh -o StrictHostKeyChecking=no\" jenkins@traf-builds.esgyn.com:$toolsrc /opt/traf",
      user     => jenkins,
      timeout  => 900,
      provider => shell,
      onlyif   => "/usr/bin/test `/usr/bin/rsync -haS --dry-run --itemize-changes --del -e \"ssh -o StrictHostKeyChecking=no\" jenkins@traf-builds.esgyn.com:$toolsrc /opt/traf | /usr/bin/wc -l` -gt 0",
      require  => [ File['/opt/traf/tools'], File['/opt/traf/build-tool-tgz'] ],
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

