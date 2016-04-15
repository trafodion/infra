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

    $hadoop_arch="https://archive.apache.org/dist/hadoop/common/hadoop-2.6.0/hadoop-2.6.0.tar.gz"
    $hbase_arch="https://archive.apache.org/dist/hbase/hbase-1.0.2/hbase-1.0.2-bin.tar.gz"
    $zoo_arch="https://archive.apache.org/dist/zookeeper/zookeeper-3.4.6/zookeeper-3.4.6.tar.gz"
    $hive_arch="https://archive.apache.org/dist/hive/hive-1.2.1/apache-hive-1.2.1-bin.tar.gz"
  }

  exec { 'download_hadoop':
    creates => "/opt/hadoop-${hadoop_ver}.tar.gz",
    cwd     => "/opt",
    command => "/usr/bin/wget $hadoop_arch",
  }
  exec { 'download_hbase':
    creates => "/opt/hbase-${hbase_ver}-bin.tar.gz",
    cwd     => "/opt",
    command => "/usr/bin/wget $hbase_arch",
  }
  exec { 'download_zoo':
    creates => "/opt/zookeeper-${zoo_ver}.tar.gz",
    cwd     => "/opt",
    command => "/usr/bin/wget $zoo_arch",
  }
  exec { 'download_hive':
    creates => "/opt/hive-${hive_ver}.tar.gz",
    cwd     => "/opt",
    command => "/usr/bin/wget $hive_arch",
  }
  exec { 'unpack_hadoop':
    creates  => "/opt/hadoop-${hadoop_ver}",
    cwd      => "/opt",
    command  => "/bin/tar xf hadoop-${hadoop_arch}.tar.gz",
    requires => Exec['download_hadoop'],
  }
  exec { 'unpack_hbase':
    creates  => "/opt/hbase-${hbase_ver}",
    cwd      => "/opt",
    command  => "/bin/tar xf hbase-${hbase_arch}-bin.tar.gz",
    requires => Exec['download_hbase'],
  }
  exec { 'unpack_zoo':
    creates  => "/opt/zookeeper-${zoo_ver}",
    cwd      => "/opt",
    command  => "/bin/tar xf zookeeper-${zoo_arch}.tar.gz",
    requires => Exec['download_zoo'],
  }
  exec { 'unpack_hive':
    creates  => "/opt/hive-${hive_ver}",
    cwd      => "/opt",
    command  => "/bin/tar xf hive-${hive_arch}.tar.gz",
    requires => Exec['download_hive'],
  }
  # hdfs data
  file { '/dfs':
    owner => 'hdfs',
    group => 'hdfs',
    mode  => '770',
    require => User['hdfs'],
  }
  class {'traf::hive_metastore':
    hive_sql_pw     => 'insecure_hive',
    hive_schema_ver => $hive_ver,
    require         => [ User['hive'], Exec['unpack_hive'], ],
  }
  user { 'hdfs':
    ensure     => present,
    gid        => 'hdfs',
  }
  user { 'hbase':
    ensure     => present,
    gid        => 'hbase',
  }
  user { 'zookeeper':
    ensure     => present,
    gid        => 'hive',
  }
  user { 'hive':
    ensure     => present,
    gid        => 'hive',
  }


}

