# == Class: traf::nondistro
#
# Single-Node hadoop set-up, only useful for simple functional testing
# Installs & runs apache hadoop, vanilla distro with no cluster mgr software
class traf::nondistro (
  $distro      = '',
) {


  # Vanilla Hadoop
  if $distro == 'VH1.0' {
    $hadoop_ver="2.6.0"
    $hbase_ver="1.0.2"
    $zoo_ver="3.4.6"
    $hive_ver="1.2.1"
    $meta_schema="1.2.0"

    $hadoop_arch="https://archive.apache.org/dist/hadoop/common/hadoop-2.6.0/hadoop-2.6.0.tar.gz"
    $hbase_arch="https://archive.apache.org/dist/hbase/hbase-1.0.2/hbase-1.0.2-bin.tar.gz"
    $zoo_arch="https://archive.apache.org/dist/zookeeper/zookeeper-3.4.6/zookeeper-3.4.6.tar.gz"
    $hive_arch="https://archive.apache.org/dist/hive/hive-1.2.1/apache-hive-1.2.1-bin.tar.gz"
  }

  exec { 'download_hadoop':
    creates => "/opt/hadoop-${hadoop_ver}.tar.gz",
    cwd     => "/opt",
    command => "/usr/bin/wget $hadoop_arch",
    require => Package['wget'],
  }
  exec { 'download_hbase':
    creates => "/opt/hbase-${hbase_ver}-bin.tar.gz",
    cwd     => "/opt",
    command => "/usr/bin/wget $hbase_arch",
    require => Package['wget'],
  }
  exec { 'download_zoo':
    creates => "/opt/zookeeper-${zoo_ver}.tar.gz",
    cwd     => "/opt",
    command => "/usr/bin/wget $zoo_arch",
    require => Package['wget'],
  }
  exec { 'download_hive':
    creates => "/opt/apache-hive-${hive_ver}-bin.tar.gz",
    cwd     => "/opt",
    command => "/usr/bin/wget $hive_arch",
    require => Package['wget'],
  }
  file { "/opt/mydistro":
    ensure  => directory,
    owner   => 'tinstall',
    group   => 'root',
    mode    => '0644',
    require => User['tinstall'],
  }
  exec { 'unpack_hadoop':
    creates  => "/opt/mydistro/hadoop-${hadoop_ver}",
    cwd      => "/opt/mydistro",
    user     => "tinstall",
    command  => "/bin/tar xf /opt/hadoop-${hadoop_ver}.tar.gz",
    require  => [ Exec['download_hadoop'], User['tinstall'], File['/opt/mydistro'] ],
  }
  exec { 'unpack_hbase':
    creates  => "/opt/mydistro/hbase-${hbase_ver}",
    cwd      => "/opt/mydistro",
    user     => "tinstall",
    command  => "/bin/tar xf /opt/hbase-${hbase_ver}-bin.tar.gz",
    require  => [ Exec['download_hbase'], User['tinstall'], File['/opt/mydistro'] ],
  }
  exec { 'unpack_zoo':
    creates  => "/opt/mydistro/zookeeper-${zoo_ver}",
    cwd      => "/opt/mydistro",
    user     => "tinstall",
    command  => "/bin/tar xf /opt/zookeeper-${zoo_ver}.tar.gz",
    require  => [ Exec['download_zoo'], User['tinstall'], File['/opt/mydistro'] ],
  }
  exec { 'unpack_hive':
    creates  => "/opt/mydistro/apache-hive-${hive_ver}-bin",
    cwd      => "/opt/mydistro",
    user     => "tinstall",
    command  => "/bin/tar xf /opt/apache-hive-${hive_ver}-bin.tar.gz",
    require  => [ Exec['download_hive'], User['tinstall'], File['/opt/mydistro'] ],
  }
  # standard paths for downstream scripting
  file { "/opt/hadoop":
    ensure  => link,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    target  => "/opt/mydistro/hadoop-${hadoop_ver}",
  }
  file { "/opt/hbase":
    ensure  => link,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    target  => "/opt/mydistro/hbase-${hbase_ver}",
  }
  file { "/var/log/hbase":
    ensure  => link,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    target  => "/opt/mydistro/hbase-${hbase_ver}/logs",
  }
  file { "/opt/zookeeper":
    ensure  => link,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    target  => "/opt/mydistro/zookeeper-${zoo_ver}",
  }
  file { "/opt/hive":
    ensure  => link,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    target  => "/opt/mydistro/apache-hive-${hive_ver}-bin",
  }

  # hdfs data
  file { '/dfs':
    ensure  => directory,
    owner   => 'tinstall',
    group   => 'tinstall',
    mode    => '770',
    require => User['tinstall'],
  }
  # zookeeper data
  file { '/home/tinstall/zookeeper':
    ensure  => directory,
    owner   => 'tinstall',
    group   => 'tinstall',
    mode    => '770',
    require => User['tinstall'],
  }
  class {'traf::hive_metastore':
    hive_sql_pw     => 'insecure_hive',
    hive_schema_ver => $meta_schema,
    hive_home       => "/opt/hive",
    require         => [ Exec['unpack_hive'], File['/opt/hive'], ],
  }

}

