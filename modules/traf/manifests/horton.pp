# == Class: traf::horton
#
# Single-Node set-up, only useful for simple functional testing
# Installs & configures a subset of HDP
class traf::horton (
  $hive_sql_pw = '',
  $distro      = '',
) {


  # Trafodion configuration for Hive
  file { '/etc/SQSystemDefaults.conf':
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('traf/SQSystemDefaults.conf.erb'),
  }


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
      'ambari-server',
    ]
    $repofile = 'puppet:///modules/traf/hadoop/horton-hdp2.1.repo'
    $repoamb = 'puppet:///modules/traf/hadoop/ambari-1.6.1.repo'
    $coresite = 'puppet:///modules/traf/hadoop/core-site.xml'
    $hdfssite = 'puppet:///modules/traf/hadoop/hdfs-site.xml'
    $hbasefile = 'hbase-site.xml-0.9'
    $hdfs_services = ['hadoop-hdfs-datanode','hadoop-hdfs-namenode']
    $zoopidfile = '/var/lib/zookeeper/zookeeper_server.pid'
    $hive_ver = '0.13.0'
  } # HDP2.1

  class {'traf::hive_metastore':
    hive_sql_pw     => $hive_sql_pw,
    hive_schema_ver => $hive_ver,
    require         => Package['hive'],
  }

  file { '/etc/yum.repos.d/horton.repo':
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    source => $repofile,
  }
  file { '/etc/yum.repos.d/ambari.repo':
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    source => $repoamb,
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
    source  => "puppet:///modules/traf/hadoop/${hbasefile}",
    require => Exec['hbase-conf'],
  }
  file { '/etc/hive/conf/hive-site.xml':
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => template('traf/hive-site.xml.erb'),
    require => Package['hive'],
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


  exec { 'zookeeper-env':
    command =>
          '/bin/echo "export ZOO_LOG_DIR=/var/log/zookeeper" >> /etc/zookeeper/conf/zookeeper-env.sh',
    unless  => '/bin/grep "/var/log/zookeeper" /etc/zookeeper/conf/zookeeper-env.sh',
    require => [Package['zookeeper-server'] ]
  }
  exec { 'zookeeper-init':
    command =>
          '/usr/lib/zookeeper/bin/zkServer.sh start /etc/zookeeper/conf/zoo.cfg',
    user    => 'zookeeper',
    creates => $zoopidfile,
    require => [Exec['zookeeper-env'],Group['zookeeper'] ]
  }
  group { 'zookeeper':
    ensure  => present,
  }
}
