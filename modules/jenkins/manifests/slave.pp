# == Class: jenkins::slave
#
class jenkins::slave(
  $ssh_key = '',
  $sudo = false,
  $bare = false,
  $user = true,
  $python3 = false,
  $include_pypy = false
) {

  include pip
  include jenkins::params

  if ($user == true) {
    class { 'jenkins::jenkinsuser':
      ensure  => present,
      sudo    => $sudo,
      ssh_key => $ssh_key,
    }
  }

  # Packages that all jenkins slaves need
  $common_packages = [
    $::jenkins::params::jdk_package, # jdk for building java jobs
    $::jenkins::params::ccache_package,
    $::jenkins::params::python_netaddr_package, # Needed for devstack address_in_net()
  ]

  # Packages that most jenkins slaves (eg, unit test runners) need
  $standard_packages = [
    $::jenkins::params::asciidoc_package, # for building gerrit/building openstack docs
    $::jenkins::params::curl_package,
    # $::jenkins::params::docbook_xml_package, # for building openstack docs
    # $::jenkins::params::docbook5_xml_package, # for building openstack docs
    # $::jenkins::params::docbook5_xsl_package, # for building openstack docs
    # $::jenkins::params::gnome_doc_package, # for generating translation files for docs
    # $::jenkins::params::graphviz_package, # for generating graphs in docs
    # $::jenkins::params::firefox_package, # for selenium tests
    $::jenkins::params::mod_wsgi_package,
    $::jenkins::params::libcurl_dev_package,
    $::jenkins::params::ldap_dev_package,
    # $::jenkins::params::librrd_dev_package, # for python-rrdtool, used by kwapi
    # $::jenkins::params::libtidy_package, # for python-tidy, used by sphinxcontrib-docbookrestapi
    $::jenkins::params::libsasl_dev, # for keystone ldap auth integration
    # $::jenkins::params::mongodb_package, # for ceilometer unit tests
    #$::jenkins::params::mysql_dev_package,
    $::jenkins::params::nspr_dev_package, # for spidermonkey, used by ceilometer
    $::jenkins::params::sqlite_dev_package,
    $::jenkins::params::libxml2_package,
    $::jenkins::params::libxml2_dev_package, # for xmllint, need for wadl
    $::jenkins::params::libxslt_dev_package,
    $::jenkins::params::libffi_dev_package, # xattr's cffi dependency
    $::jenkins::params::pandoc_package, #for docs, markdown->docbook, bug 924507
    $::jenkins::params::pkgconfig_package, # for spidermonkey, used by ceilometer
    $::jenkins::params::python_libvirt_package,
    $::jenkins::params::python_lxml_package, # for validating openstack manuals
    $::jenkins::params::python_zmq_package, # zeromq unittests (not pip installable)
    $::jenkins::params::rubygems_package,
    $::jenkins::params::sbcl_package, # cl-openstack-client testing
    $::jenkins::params::sqlite_package,
    $::jenkins::params::unzip_package,
    $::jenkins::params::xslt_package, # for building openstack docs
    # $::jenkins::params::xvfb_package, # for selenium tests
#    $::jenkins::params::zookeeper_package, # for tooz unit tests
  ]

  if ($bare == false) {
    $packages = [$common_packages, $standard_packages]
  } else {
    $packages = $common_packages
  }

  package { $packages:
    ensure => present,
  }

  case $::osfamily {
    'RedHat': {

      exec { 'yum Group Install':
        unless  => '/usr/bin/yum grouplist "Development tools" | /bin/grep "^Installed Groups"',
        command => '/usr/bin/yum -y groupinstall "Development tools"',
      }

    }
    'Debian': {

      # install build-essential package group
      package { 'build-essential':
        ensure => present,
      }

      package { $::jenkins::params::maven_package:
        ensure  => present,
        require => Package[$::jenkins::params::jdk_package],
      }

      package { $::jenkins::params::ruby1_9_1_package:
        ensure => present,
      }

      package { $::jenkins::params::ruby1_9_1_dev_package:
        ensure => present,
      }

      package { $::jenkins::params::ruby_bundler_package:
        ensure => present,
      }

      package { 'openjdk-6-jre-headless':
        ensure  => purged,
        require => Package[$::jenkins::params::jdk_package],
      }

    }
    default: {
      fail("Unsupported osfamily: ${::osfamily} The 'jenkins' module only supports osfamily Debian or RedHat (slaves only).")
    }
  }

  # Packages that need to be installed from pip
  #$pip_packages = [
  #  'setuptools-git',
  #]

  if $python3 {
    if ($::lsbdistcodename == 'precise') {
      apt::ppa { 'ppa:zulcss/py3k':
        before => Class[pip::python3],
      }
    }
    include pip::python3
    #package { $pip_packages:
    #  ensure   => latest,  # we want the latest from these
    #  provider => pip3,
    #  require  => Class[pip::python3],
    #}
    package { 'tox':
      ensure   => '1.7.2',
      provider => pip3,
      require  => Class[pip::python3],
    }
  } else {
    #package { $pip_packages:
    #  ensure   => latest,  # we want the latest from these
    #  provider => pip,
    #  require  => Class[pip],
    #}
    package { 'tox':
      ensure   => '1.7.2',
      provider => pip,
      require  => Class[pip],
    }
  }

  file { '/etc/profile.d/rubygems.sh':
    ensure => present,
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    source => 'puppet:///modules/jenkins/rubygems.sh',
  }

  file { '/usr/local/bin/gcc':
    ensure  => link,
    target  => '/usr/bin/ccache',
    require => Package['ccache'],
  }

  file { '/usr/local/bin/g++':
    ensure  => link,
    target  => '/usr/bin/ccache',
    require => Package['ccache'],
  }

  file { '/usr/local/bin/cc':
    ensure  => link,
    target  => '/usr/bin/ccache',
    require => Package['ccache'],
  }

  file { '/usr/local/bin/c++':
    ensure  => link,
    target  => '/usr/bin/ccache',
    require => Package['ccache'],
  }

## Removed all of database set-up for jenkins slaves
## Database stuff is in the traf/buildtest and related modules.

  file { '/usr/local/jenkins':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  file { '/usr/local/jenkins/slave_scripts':
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    recurse => true,
    purge   => true,
    force   => true,
    require => File['/usr/local/jenkins'],
    source  => 'puppet:///modules/jenkins/slave_scripts',
  }

  file { '/etc/sudoers.d/jenkins-sudo-grep':
    ensure => present,
    source => 'puppet:///modules/jenkins/jenkins-sudo-grep.sudo',
    owner  => 'root',
    group  => 'root',
    mode   => '0440',
  }

#  vcsrepo { '/opt/requirements':
#    ensure   => latest,
#    provider => git,
#    revision => 'master',
#    source   => 'https://git.openstack.org/openstack/requirements',
#  }

  # Temporary for debugging glance launch problem
  # https://lists.launchpad.net/openstack/msg13381.html
  # NOTE(dprince): ubuntu only as RHEL6 doesn't have sysctl.d yet
  if ($::osfamily == 'Debian') {

    file { '/etc/sysctl.d/10-ptrace.conf':
      ensure => present,
      source => 'puppet:///modules/jenkins/10-ptrace.conf',
      owner  => 'root',
      group  => 'root',
      mode   => '0444',
    }

    exec { 'ptrace sysctl':
      subscribe   => File['/etc/sysctl.d/10-ptrace.conf'],
      refreshonly => true,
      command     => '/sbin/sysctl -p /etc/sysctl.d/10-ptrace.conf',
    }

    if $include_pypy {
      apt::ppa { 'ppa:pypy/ppa': }
      package { 'pypy':
        ensure  => present,
        require => Apt::Ppa['ppa:pypy/ppa']
      }
      package { 'pypy-dev':
        ensure  => present,
        require => Apt::Ppa['ppa:pypy/ppa']
      }
    }
  }
}
