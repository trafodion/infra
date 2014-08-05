# == Class: traf::horton
#
# Single-Node set-up, only useful for simple functional testing
# Installs & configures a subset of CDH4
class traf::horton (
   $hive_sql_pw = '',
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
    owner => 'root',
    group => 'root',
    mode  => '0644',
    content => template('traf/SQSystemDefaults.conf.erb'),
  }


  if $::osfamily == 'RedHat' {
    # packages needed for a stand-alone node
    $packages = [
      'hadoop',
      'hadoop-native',
      'hadoop-pipes',
      'hadoop-sbin',
      'hadoop-namenode',
      'hadoop-datanode',
      'hadoop-libhdfs',
      # compression libs?
      'hbase',
      'hbase-master',
      'hbase-thrift',
      'hive', # hcatalog?
      'zookeeper',
      'zookeeper-server',
    ]

    file { '/etc/yum.repos.d/horton.repo':
       owner => 'root',
       group => 'root',
       mode  => '0644',
       source => 'puppet:///modules/traf/hadoop/horton-hdp1.3.repo',
    }

    package { $packages:
        ensure => present,
	require => File['/etc/yum.repos.d/horton.repo'],
    }
  } # if RedHat

  exec { 'hadoop-conf':
     command  => '/bin/cp -r /etc/hadoop/conf.empty /etc/hadoop/conf.localtest;
      /usr/sbin/alternatives --install /etc/hadoop/conf hadoop-conf /etc/hadoop/conf.localtest 50;
      /usr/sbin/alternatives --set hadoop-conf /etc/hadoop/conf.localtest',
     creates  => '/etc/hadoop/conf.localtest',
     require  => Package['hadoop'],
  }
  # config files using hadoop 1.2 properties instead of hadoop 2.0
  file { '/etc/hadoop/conf.localtest/core-site.xml':
     source => 'puppet:///modules/traf/hadoop/core-site.xml-1.2',
     require => Exec['hadoop-conf'],
  }
  file { '/etc/hadoop/conf.localtest/hdfs-site.xml':
     source => 'puppet:///modules/traf/hadoop/hdfs-site.xml-1.2',
     require => Exec['hadoop-conf'],
  }

  exec { 'hbase-conf':
     command  => '/bin/cp -r /etc/hbase/conf.dist /etc/hbase/conf.localtest;
      /usr/sbin/alternatives --install /etc/hbase/conf hbase-conf /etc/hbase/conf.localtest 50;
      /usr/sbin/alternatives --set hbase-conf /etc/hbase/conf.localtest',
     creates  => '/etc/hbase/conf.localtest',
     require  => Package['hbase'],
  }
  file { '/etc/hbase/conf.localtest/hbase-site.xml':
     owner => 'root',
     group => 'root',
     mode  => '0644',
     source => 'puppet:///modules/traf/hadoop/hbase-site.xml',
     require => Exec['hbase-conf'],
  }
  file { '/etc/hive/conf/hive-site.xml':
       owner => 'root',
       group => 'root',
       mode  => '0644',
       content => template('traf/hive-site.xml.erb'),
       require => Package['hive'],
  }
  file { '/usr/lib/hive/lib/mysql-connector-java.jar':
       owner => 'root',
       group => 'root',
       mode  => '0644',
       ensure  => link,
       target  => '/usr/share/java/mysql-connector-java.jar',
       require => [ Package['mysql-connector-java'], Package['hive'] ],
  }

  # JAVA_HOME setting needed by all hadoop commands
  exec { 'hadoop-default':
       command => '/bin/echo "export JAVA_HOME=/usr/lib/jvm/java-openjdk" >> /etc/default/hadoop',
       unless => '/bin/grep -q JAVA_HOME /etc/default/hadoop',
       require => Package['hadoop'],
  }

  # as specified in hdfs-site.xml
  file { ['/data/dfs','/data/dfs/data']:
       owner => 'hdfs',
       group => 'hdfs',
       mode  => '0755',
       ensure => directory,
       require => Package['hadoop'],
  }
  file { ['/data']:
       owner => 'root',
       group => 'root',
       mode  => '0755',
       ensure => directory,
  }
  # format name hdfs when first created
  exec { 'namenode-format':
       command   => '/usr/bin/hadoop namenode -format -force',
       user      => 'hdfs',
       require   => [ File['/data/dfs'],Exec['hadoop-default'] ],
       creates  => '/data/dfs/name',
  }
  $hdfs_services = ['hadoop-datanode','hadoop-namenode']
  # HBase services are not started, since
  # Trafodion testing stops/starts them

  service { $hdfs_services:
      ensure => running,
      subscribe => [ 
         File['/etc/hadoop/conf.localtest/hdfs-site.xml'], 
         File['/etc/hadoop/conf.localtest/core-site.xml'], 
       ],
      require => [ 
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
          '/usr/bin/hadoop fs -mkdir /user/trafodion/bulkload
	   /usr/bin/hadoop fs -chown jenkins /user/trafodion/bulkload',
      unless  => '/usr/bin/hadoop fs -ls /user/trafodion/bulkload',
      user    => 'hdfs',
      require => [ Exec['hdfs-trafodion'] ]
  }


  exec { 'zookeeper-init':
      command => 
          '/sbin/service zookeeper-server start',
     creates  => '/var/lib/zookeeper/version-2',
     require  => [Package['zookeeper-server'],Group['zookeeper'] ]
  }
  group { 'zookeeper':
     ensure  => present,
  }
}

