# == Class: traf::cloudera
#
# Single-Node set-up, only useful for simple functional testing
# Installs & configures a subset of CDH4
class traf::cloudera (
  $hive_sql_pw = '',
  $distro      = '',
) {


  class {'mysql::server':
    config_hash =>  {
      'root_password'  => 'insecure_slave',
      'default_engine' => 'MyISAM',
      'bind_address'   => '127.0.0.1',
    }
  }
  include mysql::server::account_security


  class { 'mysql::java': }
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


  # packages needed for a stand-alone node
  $common_pkg = [
    'hadoop',
    'hadoop-hdfs',
    'hadoop-hdfs-namenode',
    'hadoop-hdfs-datanode',
    'hadoop-libhdfs',
    'hadoop-mapreduce',
    'hadoop-yarn',
    'hadoop-yarn-resourcemanager',
    'hadoop-yarn-nodemanager',
    'hadoop-client',
    'hbase',
    'hbase-master',
    'hbase-thrift',
    'hive',
    'zookeeper',
    'zookeeper-server',
  ]

  if $distro == 'CDH4.4' {

    $repofile = 'cloudera-cdh4.repo'
    $repokey  = 'http://archive.cloudera.com/cdh4/redhat/6/x86_64/cdh/RPM-GPG-KEY-cloudera'
    $keyver   = 'gpg-pubkey-e8f86acd-4a418045'
    $yarnsite = 'yarn-site.xml'
    $packages = $common_pkg

  } # if CDH4.4

  if $distro == 'CDH5.1' {

    $repofile = 'cloudera-cdh5.1.repo'
    $repokey  = 'http://archive.cloudera.com/cdh5/redhat/6/x86_64/cdh/RPM-GPG-KEY-cloudera'
    $keyver   = 'gpg-pubkey-e8f86acd-4a418045'
    $yarnsite = 'yarn-site.xml-2.2'
    $packages = $common_pkg, ['hadoop-libhdfs-devel']

  } # if CDH5.1

  file { "/etc/yum.repos.d/${repofile}":
    owner  => 'root',
    group  => 'root',
    mode   => '0644',
    source => "puppet:///modules/traf/hadoop/${repofile}",
  }
  exec { 'cloudera rpm' :
    command => "/bin/rpm --import ${repokey}",
    unless  => "/bin/rpm -qa gpg-pubkey* | grep -q ${keyver}",
    require => File["/etc/yum.repos.d/${repofile}"],
  }

  package { $packages:
    ensure  => present,
    require => Exec['cloudera rpm'],
  }

  exec { 'hadoop-conf':
    command => '/bin/cp -r /etc/hadoop/conf.dist /etc/hadoop/conf.localtest;
      /usr/sbin/alternatives --install /etc/hadoop/conf hadoop-conf /etc/hadoop/conf.localtest 50;
      /usr/sbin/alternatives --set hadoop-conf /etc/hadoop/conf.localtest',
    creates => '/etc/hadoop/conf.localtest',
    require => Package['hadoop'],
  }
  file { '/etc/hadoop/conf.localtest/core-site.xml':
    source  => 'puppet:///modules/traf/hadoop/core-site.xml',
    require => Exec['hadoop-conf'],
  }
  file { '/etc/hadoop/conf.localtest/hdfs-site.xml':
    source  => 'puppet:///modules/traf/hadoop/hdfs-site.xml',
    require => Exec['hadoop-conf'],
  }
  file { '/etc/hadoop/conf.localtest/mapred-site.xml':
    source  => 'puppet:///modules/traf/hadoop/mapred-site.xml',
    require => Exec['hadoop-conf'],
  }
  file { '/etc/hadoop/conf.localtest/yarn-site.xml':
    source  => "puppet:///modules/traf/hadoop/${yarnsite}",
    require => Exec['hadoop-conf'],
  }

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
  # No longer needed -- make it absent after HBase on HDFS change is fully propagated
  file { ['/var/hbase']:
    ensure  => absent,
    recurse => true,
    force   => true,
  }

  # as specified in hdfs-site.xml
  file { ['/data/dfs','/data/dfs/data']:
    ensure  => directory,
    owner   => 'hdfs',
    group   => 'hdfs',
    mode    => '0770',
    require => Package['hadoop-hdfs'],
  }
  file { ['/data']:
    ensure => directory,
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }
  # format name hdfs when first created
  exec { 'namenode-format':
    command => '/usr/bin/hdfs namenode -format -force',
    user    => 'hdfs',
    require => File['/data/dfs'],
    creates => '/data/dfs/name',
  }
  file { ['/var/log/hadoop-yarn','/var/log/hadoop-yarn/containers','/var/log/hadoop-yarn/apps']:
    ensure  => directory,
    owner   => 'yarn',
    group   => 'yarn',
    mode    => '0755',
    require => Package['hadoop-yarn'],
  }
  $hdfs_services = ['hadoop-hdfs-datanode','hadoop-hdfs-namenode']
  $yarn_services = ['hadoop-yarn-resourcemanager','hadoop-yarn-nodemanager']
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
  service { $yarn_services:
    ensure    => running,
    subscribe => [
      File['/etc/hadoop/conf.localtest/yarn-site.xml'],
      File['/etc/hadoop/conf.localtest/mapred-site.xml'],
    ],
    require   => [
      Exec['hdfs-tmp'],
      Exec['hdfs-userhist'],
      Exec['hdfs-yarnlog'],
    ],
  }
  exec { 'hdfs-tmp':
    command => '/usr/bin/hadoop fs -mkdir -p /tmp && /usr/bin/hadoop fs -chmod 1777 /tmp',
    unless  => '/usr/bin/hadoop fs -ls -d /tmp',
    user    => 'hdfs',
    require => Service[$hdfs_services],
  }
  # /user is specified in yarn-site.xml
  exec { 'hdfs-userhist':
    command =>
      '/usr/bin/hadoop fs -mkdir -p /user/history
       /usr/bin/hadoop fs -chmod 1777 /user/history
	   /usr/bin/hadoop fs -chown yarn /user/history',
    unless  => '/usr/bin/hadoop fs -ls -d /user/history',
    user    => 'hdfs',
    require => Service[$hdfs_services],
  }
  exec { 'hdfs-yarnlog':
    command =>
      '/usr/bin/hadoop fs -mkdir -p /var/log/hadoop-yarn
	   /usr/bin/hadoop fs -chown yarn:mapred /var/log/hadoop-yarn',
    unless  => '/usr/bin/hadoop fs -ls -d /var/log/hadoop-yarn',
    user    => 'hdfs',
    require => Service[$hdfs_services],
  }
  exec { 'hdfs-jenkins':
    command =>
      '/usr/bin/hadoop fs -mkdir -p /user/jenkins
	   /usr/bin/hadoop fs -chown jenkins /user/jenkins',
    unless  => '/usr/bin/hadoop fs -ls -d /user/jenkins',
    user    => 'hdfs',
    require => [ Service[$hdfs_services],User['jenkins'] ]
  }
  exec { 'hdfs-hive-dir':
    command =>
          '/usr/bin/hadoop fs -mkdir -p /user/hive
	   /usr/bin/hadoop fs -chown jenkins /user/hive',
    unless  => '/usr/bin/hadoop fs -ls -d /user/hive',
    user    => 'hdfs',
    require => [ Service[$hdfs_services],User['jenkins'] ]
  }
  # HDFS directories for Bulkload feature
  exec { 'hdfs-hbase-staging':
    command =>
      '/usr/bin/hadoop fs -mkdir -p /hbase-staging
	   /usr/bin/hadoop fs -chmod 711 /hbase-staging
	   /usr/bin/hadoop fs -chown hbase /hbase-staging',
    unless  => '/usr/bin/hadoop fs -ls -d /hbase-staging',
    user    => 'hdfs',
    require => [ Service[$hdfs_services],User['jenkins'] ]
  }
  exec { 'hdfs-trafodion':
    command =>
      '/usr/bin/hadoop fs -mkdir -p /user/trafodion
	   /usr/bin/hadoop fs -chown jenkins /user/trafodion',
    unless  => '/usr/bin/hadoop fs -ls -d /user/trafodion',
    user    => 'hdfs',
    require => [ Service[$hdfs_services],User['jenkins'] ]
  }
  exec { 'hdfs-trafodion-bulkload':
    command =>
      '/usr/bin/hadoop fs -mkdir -p /bulkload
	   /usr/bin/hadoop fs -chown jenkins /bulkload',
    unless  => '/usr/bin/hadoop fs -ls -d /bulkload',
    user    => 'hdfs',
    require => [ Exec['hdfs-trafodion'] ]
  }


  exec { 'zookeeper-init':
    command => '/sbin/service zookeeper-server init',
    creates => '/var/lib/zookeeper/version-2',
    require => Package['zookeeper-server'],
  }
}

