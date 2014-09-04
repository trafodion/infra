# == Class: traf::horton
#
# Single-Node set-up, only useful for simple functional testing
# Installs & configures a subset of HDP
class traf::horton (
  $hive_sql_pw = '',
  $distro      = '',
) {


  class {'mysql::server':
    root_password    => 'insecure_slave',
    override_options =>  {
      'mysqld' => {
        'default_engine' => 'MyISAM',
        'bind_address'   => '127.0.0.1',
      }
    }
  }
  include mysql::server::account_security


  class { 'mysql::bindings':
    java_enable  => true,
  }

  mysql::db { 'metastore':
    user     => 'hive',
    charset  => 'latin1',
    password => $hive_sql_pw,
    host     => 'localhost',
    sql      => '/usr/lib/hive/scripts/metastore/upgrade/mysql/hive-schema-0.9.0.mysql.sql',
    # For now Trafodion requires 0.9.0
    grant    => ['all'],   # lets see if autoschema works
    # if we need to be more restrictive, Hive docs say:
    #grant    => ['Select_priv','Insert_priv','Update_priv',
    #             'Delete_priv','Lock_tables_priv','Execute_priv'],
    require  => Package['hive'],
  }

  # Trafodion configuration for Hive
  file { '/etc/SQSystemDefaults.conf':
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('traf/SQSystemDefaults.conf.erb'),
  }


  if $distro == 'HDP1.3' {
    # packages needed for a stand-alone node
    $packages = [
      'hadoop',
      'hadoop-native',
      'hadoop-pipes',
      'hadoop-sbin',
      'hadoop-namenode',
      'hadoop-datanode',
      'hadoop-libhdfs',
      'hbase',
      'hbase-master',
      'hbase-thrift',
      'hive',
      'hcatalog',
      'zookeeper',
      'zookeeper-server',
    ]
    $repofile = 'puppet:///modules/traf/hadoop/horton-hdp1.3.repo'
    $coresite = 'puppet:///modules/traf/hadoop/core-site.xml-1.2'
    $hdfssite = 'puppet:///modules/traf/hadoop/hdfs-site.xml-1.2'
    $hdfs_services = ['hadoop-datanode','hadoop-namenode']
    $zoopidfile = '/var/lib/zookeeper/version-2/snapshot-0'
  } # HDP1.3
  if $distro == 'HDP2.1' {
    $packages = [
      'hadoop',
      'hadoop-hdfs',
      'hadoop-hdfs-namenode',
      'hadoop-hdfs-datanode',
      'hadoop-libhdfs',
      'hadoop-yarn',
      'hadoop-mapreduce',
      'hadoop-client',
      'hbase',
      'hbase-thrift',
      'hive',
      'hive-hcatalog',
      'zookeeper',
      'zookeeper-server',
    ]
    $repofile = 'puppet:///modules/traf/hadoop/horton-hdp2.1.repo'
    $coresite = 'puppet:///modules/traf/hadoop/core-site.xml'
    $hdfssite = 'puppet:///modules/traf/hadoop/hdfs-site.xml'
    $hdfs_services = ['hadoop-hdfs-datanode','hadoop-hdfs-namenode']
    $zoopidfile = '/var/lib/zookeeper/zookeeper_server.pid'
  } # HDP2.1

  file { '/etc/yum.repos.d/horton.repo':
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    source => $repofile,
  }

  package { $packages:
    ensure  => present,
    require => File['/etc/yum.repos.d/horton.repo'],
  }

  exec { 'hadoop-conf':
    command => '/bin/cp -r /etc/hadoop/conf.empty /etc/hadoop/conf.localtest;
      /usr/sbin/alternatives --install /etc/hadoop/conf hadoop-conf /etc/hadoop/conf.localtest 50;
      /usr/sbin/alternatives --set hadoop-conf /etc/hadoop/conf.localtest',
    creates => '/etc/hadoop/conf.localtest',
    require => Package['hadoop'],
  }
  file { '/etc/hadoop/conf.localtest/core-site.xml':
    source  => $coresite,
    require => Exec['hadoop-conf'],
  }
  file { '/etc/hadoop/conf.localtest/hdfs-site.xml':
    source  => $hdfssite,
    require => Exec['hadoop-conf'],
  }
  if $distro == 'HDP2.1' {
    file { '/etc/hadoop/conf.localtest/mapred-site.xml':
      source  => 'puppet:///modules/traf/hadoop/mapred-site.xml',
      require => Exec['hadoop-conf'],
    }
    ##### Yarn managers not set up as standard services. 
    #     /usr/lib/hadoop/sbin/yarn-daemon.sh 
    #     No way to easy way to check if it is already running
    #     Skip yarn set-up. Not required by trafodion at this point.

  } # HDP2.1 

  exec { 'hbase-conf':
    command => '/bin/cp -r /etc/hbase/conf.dist /etc/hbase/conf.localtest;
      /usr/sbin/alternatives --install /etc/hbase/conf hbase-conf /etc/hbase/conf.localtest 50;
      /usr/sbin/alternatives --set hbase-conf /etc/hbase/conf.localtest',
    creates => '/etc/hbase/conf.localtest',
    require => Package['hbase'],
  }
  file { '/etc/hbase/conf.localtest/hbase-site.xml':
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    source  => 'puppet:///modules/traf/hadoop/hbase-site.xml',
    require => Exec['hbase-conf'],
  }
  file { '/etc/hive/conf/hive-site.xml':
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('traf/hive-site.xml.erb'),
    require => Package['hive'],
  }
  file { '/usr/lib/hive/lib/mysql-connector-java.jar':
    ensure  => link,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    target  => '/usr/share/java/mysql-connector-java.jar',
    require => [ Package['mysql-connector-java'], Package['hive'] ],
  }

  # Both JAVA_HOME setting methods don't conflict, so we'll do both

  # JAVA_HOME setting for HDP1
  exec { 'hadoop-default':
    command => '/bin/echo "export JAVA_HOME=/usr/lib/jvm/java-openjdk" >> /etc/default/hadoop',
    unless  => '/bin/grep -q JAVA_HOME /etc/default/hadoop',
    require => Package[$packages],
  }
  # JAVA_HOME setting for HDP2
  file { '/usr/lib/bigtop-utils/bigtop-detect-javahome':
    owner   => 'root',
    group   => 'root',
    mode    => '0444',
    content => 'export JAVA_HOME=/usr/lib/jvm/java-openjdk',
    require => File['/usr/lib/bigtop-utils'],
  }
  file { '/usr/lib/bigtop-utils':
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0444',
  }

  # as specified in hdfs-site.xml
  file { ['/data/dfs','/data/dfs/data']:
    ensure  => directory,
    owner   => 'hdfs',
    group   => 'hdfs',
    mode    => '0755',
    require => Package['hadoop'],
  }
  file { ['/data']:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }
  # format name hdfs when first created
  exec { 'namenode-format':
    command => '/usr/bin/hadoop namenode -format -force',
    user    => 'hdfs',
    require => [ File['/data/dfs'],Exec['hadoop-default'],File['/usr/lib/bigtop-utils/bigtop-detect-javahome'] ],
    creates => '/data/dfs/name',
  }
  # HBase services are not started, since
  # Trafodion testing stops/starts them

  service { $hdfs_services:
    ensure    => running,
    subscribe => [
      File['/etc/hadoop/conf.localtest/hdfs-site.xml'],
      File['/etc/hadoop/conf.localtest/core-site.xml'],
    ],
    require   => [
      Exec['namenode-format'],
    ],
  }
  exec { 'hdfs-tmp':
    command => '/usr/bin/hadoop fs -mkdir /tmp && /usr/bin/hadoop fs -chmod 1777 /tmp',
    unless  => '/usr/bin/hadoop fs -ls /tmp',
    user    => 'hdfs',
    require => Service[$hdfs_services],
  }
  exec { 'hdfs-jenkins':
    command =>
      '/usr/bin/hadoop fs -mkdir /user/jenkins
	   /usr/bin/hadoop fs -chown jenkins /user/jenkins',
    unless  => '/usr/bin/hadoop fs -ls /user/jenkins',
    user    => 'hdfs',
    require => [ Service[$hdfs_services],User['jenkins'] ]
  }
  exec { 'hdfs-hive-dir':
    command =>
      '/usr/bin/hadoop fs -mkdir /user/hive
	   /usr/bin/hadoop fs -chown jenkins /user/hive',
    unless  => '/usr/bin/hadoop fs -ls /user/hive',
    user    => 'hdfs',
    require => [ Service[$hdfs_services],User['jenkins'] ]
  }
  # HBase on HDFS, specified in hbase-site.xml
  exec { 'hdfs-hbase':
    command =>
      '/usr/bin/hadoop fs -mkdir /hbase
	   /usr/bin/hadoop fs -chown hbase:hbase /hbase',
    unless  => '/usr/bin/hadoop fs -ls /hbase',
    user    => 'hdfs',
    require => [ Service[$hdfs_services],Package['hbase'] ]
  }
  # HDFS directories for Bulkload feature
  exec { 'hdfs-hbase-staging':
    command =>
      '/usr/bin/hadoop fs -mkdir /hbase-staging
	   /usr/bin/hadoop fs -chmod 711 /hbase-staging
	   /usr/bin/hadoop fs -chown hbase /hbase-staging',
    unless  => '/usr/bin/hadoop fs -ls /hbase-staging',
    user    => 'hdfs',
    require => [ Service[$hdfs_services],User['jenkins'] ]
  }
  exec { 'hdfs-trafodion':
    command =>
          '/usr/bin/hadoop fs -mkdir /user/trafodion
	   /usr/bin/hadoop fs -chown jenkins /user/trafodion',
    unless  => '/usr/bin/hadoop fs -ls /user/trafodion',
    user    => 'hdfs',
    require => [ Service[$hdfs_services],User['jenkins'] ]
  }
  exec { 'hdfs-trafodion-bulkload':
    command =>
      '/usr/bin/hadoop fs -mkdir /bulkload
	   /usr/bin/hadoop fs -chown jenkins /bulkload',
    unless  => '/usr/bin/hadoop fs -ls /bulkload',
    user    => 'hdfs',
    require => [ Exec['hdfs-trafodion'] ]
  }


  exec { 'zookeeper-init':
    command =>
          '/usr/lib/zookeeper/bin/zkServer.sh start /etc/zookeeper/conf/zoo.cfg',
    user    => 'zookeeper',
    creates => $zoopidfile,
    require => [Package['zookeeper-server'],Group['zookeeper'] ]
  }
  group { 'zookeeper':
    ensure  => present,
  }
}

